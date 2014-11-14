component extends="testbox.system.BaseSpec" {

	function run() {

		describe("Mocktory", function () {

			beforeEach(function () {
				mocktory = new mocktory.Mocktory($mockbox);
			});

			describe("creating mocks", function () {

				it("for descriptors without result descriptors", function () {

					descriptor = {
						$class: "test.Stub",
						numeric: 1,
						string: "string",
						date: CreateDate(2000, 1, 1),
						boolean: true,
						struct: {a: 1, b: 2},
						array: [1, 2],
						stub: {
							$class: "test.Stub",
							id: RandRange(1, 1000)
						}
					}

					mock = mocktory.mock(descriptor);

					expect(mock).toBeInstanceOf(descriptor.$class);
					expect(mock.getNumeric()).toBe(descriptor.numeric);
					expect(mock.getString()).toBe(descriptor.string);
					expect(mock.getDate()).toBe(descriptor.date);
					expect(mock.getBoolean()).toBe(descriptor.boolean);
					expect(mock.getStruct()).toBe(descriptor.struct);
					expect(mock.getArray()).toBe(descriptor.array);
					expect(mock.getStub()).toBeInstanceOf(descriptor.stub.$class);
					expect(mock.getStub().getId()).toBe(descriptor.stub.id);

				});

				it("for descriptors with result desciptors", function () {

					var id = RandRange(1, 1000);
					descriptor = {
						$class: "test.Stub",
						returns: {$returns: "string"},
						results: {$results: [1, 2]},
						callback: {
							$callback: function () {
								return id;
							}
						}
					}

					mock = mocktory.mock(descriptor);

					expect(mock.getReturns()).toBe(descriptor.returns.$returns);

					expect(mock.getResults()).toBe(descriptor.results.$results[1]);
					expect(mock.getResults()).toBe(descriptor.results.$results[2]);

					expect(mock.getCallback()).toBe(id);

				});

				it("for descriptors with result descriptors with arguments", function () {
					var descriptor = {
						$class: "test.Stub",
						existingMethod: [
							{
								$args: [1],
								$returns: "one"
							},
							{
								$args: [2],
								$returns: "two"
							}
						]
					}

					mock = mocktory.mock(descriptor);

					expect(mock.existingMethod(1)).toBe(descriptor.existingMethod[1].$returns);
					expect(mock.existingMethod(2)).toBe(descriptor.existingMethod[2].$returns);
				});

			});

			describe("verifying mocks", function () {

				it("should assert the number of calls is equal to $times", function () {
					var descriptor = {
						$class: "test.Stub",
						twice: {
							$returns: 1,
							$times: 2
						}
					}

					mock = mocktory.mock(descriptor);
					mock.getTwice();

					verifyShouldFail(mock);
					mock.getTwice();

					mocktory.verify(mock);

					mock.getTwice();
					verifyShouldFail(mock);
				});

				it("should assert the number of calls is at least $atLeast", function () {
					var descriptor = {
						$class: "test.Stub",
						twice: {
							$returns: 1,
							$atLeast: 2
						}
					}

					mock = mocktory.mock(descriptor);
					mock.getTwice();
					mock.getTwice();
					verifyShouldFail(mock);

					mock.getTwice();
					mocktory.verify(mock);

					mock.getTwice();
					mocktory.verify(mock);
				});

				it("should assert the number of calls is at most $atMost", function () {
					var descriptor = {
						$class: "test.Stub",
						twice: {
							$returns: 1,
							$atMost: 3
						}
					}

					mock = mocktory.mock(descriptor);

					mocktory.verify(mock);
					mock.getTwice();
					mock.getTwice();
					mock.getTwice();
					mocktory.verify(mock);

					mock.getTwice();
					verifyShouldFail(mock);
				});

				it("should assert the number of calls is between the values specified in $between", function () {
					var descriptor = {
						$class: "test.Stub",
						twice: {
							$returns: 1,
							$between: [2, 3]
						}
					}

					mock = mocktory.mock(descriptor);

					mock.getTwice();
					verifyShouldFail(mock);
					mock.getTwice();
					mocktory.verify(mock);
					mock.getTwice();
					mocktory.verify(mock);

					mock.getTwice();
					verifyShouldFail(mock);
				});

				describe("with another mock descriptor", function () {

					it("should override existing descriptors", function () {
						// Create a descriptor with a verification, and override it in the verify call.
						var descriptor = {
							$class: "test.Stub",
							twice: {
								$returns: 1,
								$times: 2
							}
						}
						var result = {
							twice: {
								$times: 1
							}
						}

						mock = mocktory.mock(descriptor);
						mock.getTwice();

						mocktory.verify(mock, result);

						mock.getTwice();
						verifyShouldFail(mock, result);
					});

					it("should append to existing descriptors", function () {
						var descriptor = {
							$class: "test.Stub",
							once: 1,
							twice: 2
						}
						var result = {
							once: {
								$times: 1
							},
							twice: {
								$times: 2
							}
						}

						mock = mocktory.mock(descriptor)

						mock.getTwice();
						verifyShouldFail(mock, result);

						mock.getTwice();
						verifyShouldFail(mock, result);

						mock.getOnce();
						mocktory.verify(mock, result);
					});

					it("should verify mocks created with MockBox", function () {
						mock = createMock("test.Stub");
						mock.$("getOnce", 1);

						var result = {
							// This time also test with arguments.
							once: [
								{
									$args: [1],
									$times: 1
								},
								{
									$args: [2],
									$times: 1
								}
							]
						}

						mock.getOnce(1);
						verifyShouldFail(mock, result);

						mock.getOnce(2);
						mocktory.verify(mock, result);
					});

				});

			});

		});

	}

	function verifyShouldFail(mock, descriptor) {
		try {
			if (IsNull(arguments.descriptor)) {
				mocktory.verify(arguments.mock);
			} else {
				mocktory.verify(arguments.mock, arguments.descriptor)
			}
			fail("an assertion should have failed");
		} catch (TestBox.AssertionFailed e) {}
	}

}