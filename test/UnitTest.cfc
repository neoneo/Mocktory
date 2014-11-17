component extends="testbox.system.BaseSpec" {

	function run() {

		describe("Mocktory", function () {

			beforeEach(function () {
				mockboxMock = $mockbox.createMock("testbox.system.MockBox");
				mocktory = new mocktory.Mocktory(mockboxMock);
			});

			describe(".isMockDescriptor", function () {

				it("should return true if the descriptor contains $class, $object or $interface", function () {
					expect(mocktory.isMockDescriptor({})).toBeFalse();
					expect(mocktory.isMockDescriptor({someKey: "Stub"})).toBeFalse();

					expect(mocktory.isMockDescriptor({$class: "class"})).toBeTrue();
					expect(mocktory.isMockDescriptor({$object: "object"})).toBeTrue();
					expect(mocktory.isMockDescriptor({$class: "class", $object: "object"})).toBeTrue();
					expect(mocktory.isMockDescriptor({$interface: "interface"})).toBeTrue();
				});

				it("should return false if the descriptor is an object", function () {
					var object = new Stub();
					object.$class = "Stub";
					expect(mocktory.isMockDescriptor(object)).toBeFalse();
				});

			});

			describe(".isResultDesciptor", function () {

				it("should return true if the descriptor contains $results, $callback or $returns", function () {
					expect(mocktory.isResultDescriptor({})).toBeFalse();
					expect(mocktory.isResultDescriptor({someKey: "value"})).toBeFalse();

					expect(mocktory.isResultDescriptor({$results: "results"})).toBeTrue();
					expect(mocktory.isResultDescriptor({$callback: "callback"})).toBeTrue();
					expect(mocktory.isResultDescriptor({$returns: "returns"})).toBeTrue();
					expect(mocktory.isResultDescriptor({$returns: JavaCast("null", 0)})).toBeTrue();
				});

				it("should return false if the descriptor is an object", function () {
					var object = new Stub();
					object.$returns = "Stub";
					expect(mocktory.isResultDescriptor(object)).toBeFalse();
				});

			});

			describe("mocking", function () {

				describe("objects", function () {

					beforeEach(function () {
						var mock = $mockbox.createMock("test.Stub");
						mockboxMock.$("createMock", mock);
						mockboxMock.$("prepareMock", mock);
						mockboxMock.$("createStub", mock);
					});

					it("should throw IllegalArgumentException if the descriptor is invalid", function () {
						descriptor = {string: "string"}

						expect(function () {
							mocktory.mock(descriptor);
						}).toThrow("IllegalArgumentException");
					});

					it("should call mockbox.createMock if there is a $class key but no $object key", function () {
						descriptor = {$class: "Stub"}

						mocktory.mock(descriptor);

						expect(mockboxMock.$count("createMock")).toBe(1);
						expect(mockboxMock.$count("prepareMock")).toBe(0);
						expect(mockboxMock.$count("createStub")).toBe(0);
					});

					it("should call mockbox.prepareMock if there is a $object key", function () {
						descriptor = {$object: new Stub()}

						mocktory.mock(descriptor);

						expect(mockboxMock.$count("createMock")).toBe(0);
						expect(mockboxMock.$count("prepareMock")).toBe(1);
						expect(mockboxMock.$count("createStub")).toBe(0);

						// Also test in presence of $class.
						mockboxMock.$reset();

						descriptor = {$object: new Stub(), $class: "Stub"}

						mocktory.mock(descriptor);

						expect(mockboxMock.$count("createMock")).toBe(0);
						expect(mockboxMock.$count("prepareMock")).toBe(1);
						expect(mockboxMock.$count("createStub")).toBe(0);
					});

					it("should call mockbox.createStub if there is a $interface key but no $class or $object key", function () {
						descriptor = {$interface: "Stub"}

						mocktory.mock(descriptor);

						expect(mockboxMock.$count("createMock")).toBe(0);
						expect(mockboxMock.$count("prepareMock")).toBe(0);
						expect(mockboxMock.$count("createStub")).toBe(1);
						var args = mockboxMock.$callLog().createStub[1];
						expect(args).toHaveKey("implements");
						expect(args.implements).toBe("Stub");
					});

					it("should set empty assertion messages if not defined", function () {
						descriptor = {
							$class: "test.Stub",
							existingMethod: {
								$returns: "value",
								$atLeast: [1, "at least"],
								$atMost: [2],
								$between: [3, 4],
								$times: 5
							}
						}

						var mock = mocktory.mock(descriptor);

						// Get the mock descriptor. Its 'existingMethod' key contains an array of method calls to spy on.
						var call = mock._mockDescriptor.existingMethod[1];
						expect(call.$atLeast).toBe(descriptor.existingMethod.$atLeast);
						expect(call.$atMost).toBe(descriptor.existingMethod.$atMost.append(""));
						expect(call.$between).toBe(descriptor.existingMethod.$between.append(""));
						expect(call.$times).toBe([descriptor.existingMethod.$times, ""]);
					});

				});

				describe("functions", function () {

					beforeEach(function () {
						var mock = $mockbox.createMock("test.Stub");
						mockboxMock.$("createMock", mock);
						// For all following tests, we need to mock some methods on the mocktory itself.
						$mockbox.prepareMock(mocktory);
						// Mock the (private) mockFunction method, to be able to spy on it.
						mocktory.$("mockFunction");
					})

					it("should create them on the mock object", function () {
						descriptor = {
							$class: "test.Stub",
							property: "value"
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(1);
						var callArgs = mocktory.$callLog().mockFunction[1];
						// Arguments: mock - function name - result descriptor
						$assert.isSameInstance(mock, callArgs[1]);
					})

					it("should mock a getter if there is no function by the given key", function () {
						descriptor = {
							$class: "test.Stub",
							property: "value"
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(1);
						var callArgs = mocktory.$callLog().mockFunction[1];
						expect(callArgs[2]).toBe("getproperty");
					});

					it("should mock the function if there exists a function by the given key", function () {
						descriptor = {
							$class: "test.Stub",
							existingMethod: "value"
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(1);
						var callArgs = mocktory.$callLog().mockFunction[1];
						expect(callArgs[2]).toBe("existingMethod");
					});

					it("should create result descriptors for simple values", function () {
						descriptor = {
							$class: "test.Stub",
							property: "value"
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(1);
						var callArgs = mocktory.$callLog().mockFunction[1];
						expect(callArgs[3]).toBe({$returns: "value"});
					});

					it("should mock functions that return null / void", function () {
						descriptor = {
							$class: "test.Stub",
							voidMethod: JavaCast("null", 0)
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(1);
						var callArgs = mocktory.$callLog().mockFunction[1];
						expect(IsNull(callArgs[3].$returns)).toBeTrue();
					});

					it("should mock functions based on a single result descriptor", function () {
						descriptor = {
							$class: "test.Stub",
							existingMethod: {
								$returns: "value"
							}
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(1);
						var callArgs = mocktory.$callLog().mockFunction[1];
						expect(callArgs[3]).toBe(descriptor.existingMethod);
					});

					it("should mock multiple function calls based on an array of result descriptors", function () {
						descriptor = {
							$class: "test.Stub",
							existingMethod: [
								{$returns: "value1"},
								{$returns: "value2"}
							]
						}

						var mock = mocktory.mock(descriptor);

						expect(mocktory.$count("mockFunction")).toBe(2);
						var callLog = mocktory.$callLog().mockFunction;
						expect(callLog[1][3]).toBe(descriptor.existingMethod[1]);
						expect(callLog[2][3]).toBe(descriptor.existingMethod[2]);
					});

				});

				describe("return values", function () {

					beforeEach(function () {
						mockboxMock.$("createMock").$callback(function () {
							var mock = $mockbox.createMock("test.Stub");
							// Mock the $ functions on the mock.
							mock.$("$args", mock);
							mock.$("$callback", mock);
							mock.$("$results", mock);
							mock.$("$", mock);

							return mock;
						});
					});

					describe("using result descriptors", function () {

						it("should mock a single result with the $returns key", function () {
							descriptor = {
								$class: "test.Stub",
								existingMethod: {
									$returns: "one"
								}
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("existingMethod");
							expect(mock.$count("$results")).toBe(1);
							expect(callLog.$results[1]).toBe([descriptor.existingMethod.$returns]);
						});

						it("should mock multiple results with the $results key", function () {
							descriptor = {
								$class: "test.Stub",
								existingMethod: {
									$results: ["one", "two"]
								}
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("existingMethod");
							expect(mock.$count("$results")).toBe(1);
							expect(callLog.$results[1]).toBe(descriptor.existingMethod.$results);
						});

						it("should mock a callback using the $callback key", function () {
							descriptor = {
								$class: "test.Stub",
								existingMethod: {
									$callback: function () {
										return "one";
									}
								}
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("existingMethod");
							expect(mock.$count("$callback")).toBe(1);
							$assert.isSameInstance(descriptor.existingMethod.$callback, callLog.$callback[1][1]);
						});

						it("should set arguments with the $args key", function () {
							descriptor = {
								$class: "test.Stub",
								existingMethod: {
									$returns: "one",
									$args: [1]
								}
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("existingMethod");
							expect(mock.$count("$args")).toBe(1);
							expect(callLog.$args[1]).toBe(descriptor.existingMethod.$args);
						});

					});

					describe("using value types", function () {

						it("should set a single return value if the value is an array of something other than result descriptors", function () {
							descriptor = {
								$class: "test.Stub",
								property: [1, 2, 3]
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("getproperty");
							expect(mock.$count("$results")).toBe(1);
							expect(callLog.$results[1][1]).toBe(descriptor.property);
						});

						it("should set a single return value if the value is a struct that is not a result descriptor", function () {
							descriptor = {
								$class: "test.Stub",
								property: {a: 1, b: 2}
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("getproperty");
							expect(mock.$count("$results")).toBe(1);
							expect(callLog.$results[1][1]).toBe(descriptor.property);
						});

						it("should set a mock object as return value if the value is a mock descriptor", function () {
							descriptor = {
								$class: "test.Stub",
								property: {
									$class: "test.Stub"
								}
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("getproperty");
							expect(mock.$count("$results")).toBe(1);
							expect(callLog.$results[1][1]).toBeInstanceOf(descriptor.property.$class);
						});

						it("should set an array of mock objects as return value if the value is an array of mock descriptors", function () {
							descriptor = {
								$class: "test.Stub",
								property: [
									{$class: "test.Stub"},
									{$class: "test.Stub"}
								]
							}

							var mock = mocktory.mock(descriptor);

							var callLog = mock.$callLog();
							expect(mock.$count("$")).toBe(1);
							expect(callLog.$[1][1]).toBe("getproperty");
							expect(mock.$count("$results")).toBe(1);
							callLog.$results[1][1].each(function (argument, index) {
								expect(arguments.argument).toBeInstanceOf(descriptor.property[arguments.index].$class);
							});
						});

					});

				});

			});

			describe("with expand mapping closure", function () {

				beforeEach(function () {
					var mock = $mockbox.createMock("test.Stub");
					mockboxMock.$("createMock", mock);
					mockboxMock.$("createStub", mock);
					prepareMock(mocktory).$("expand", "test.Stub"); // Mock the expand closure.
				});

				it("should call the closure if the descriptor is a string", function () {
					mocktory.mock("Stub");
					expect(mockboxMock.$count("createMock")).toBe(1);
					expect(mockboxMock.$callLog().createMock[1][1]).toBe("test.Stub");
				});

				it("should call the closure if the descriptor has a $class key", function () {
					mocktory.mock({
						$class: "Stub"
					});
					expect(mockboxMock.$count("createMock")).toBe(1);
					expect(mockboxMock.$callLog().createMock[1][1]).toBe("test.Stub");
				});

				it("should call the closure if the descriptor has a $interface key", function () {
					mocktory.mock({
						$interface: "Stub"
					});
					expect(mockboxMock.$count("createStub")).toBe(1);
					expect(mockboxMock.$callLog().createStub[1][1]).toBe("test.Stub");
				});

			});

		});


	}

}