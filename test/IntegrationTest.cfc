component extends="testbox.system.BaseSpec" {

	function run() {

		describe("Mocktory", function () {

			beforeEach(function () {
				mockbox = new testbox.system.MockBox();
				mocktory = new mocktory.Mocktory(mockbox);
			});

			describe("creating mocks", function () {

				it("for descriptors without result descriptors", function () {

					descriptor = {
						$class: "mocktorytest.Stub",
						numeric: 1,
						string: "string",
						date: CreateDate(2000, 1, 1),
						boolean: true,
						struct: {a: 1, b: 2},
						array: [1, 2],
						stub: {
							$class: "mocktorytest.Stub",
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
						$class: "mocktorytest.Stub",
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
						$class: "mocktorytest.Stub",
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
						$class: "mocktorytest.Stub",
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
						$class: "mocktorytest.Stub",
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
						$class: "mocktorytest.Stub",
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
						$class: "mocktorytest.Stub",
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

			});

		});


	}

	function verifyShouldFail(mock) {
		try {
			mocktory.verify(arguments.mock);
			fail("an assertion should have failed");
		} catch (TestBox.AssertionFailed e) {}
	}

}