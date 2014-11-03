Mocktory
========

Mocktory provides a simple DSL for quickly creating and verifying mocks using [TestBox](http://wiki.coldbox.org/wiki/TestBox.cfm) and [MockBox](http://wiki.coldbox.org/wiki/MockBox.cfm).
Its goal is to make setting up and mocking dependencies more readable, easier and faster.

Usage
-----
In your TestBox bundle, create a Mocktory instance:

	mocktory = new Mocktory($mockbox);

To create a mock create a descriptor, which is just a struct with some special keys prepended with `$`. Then call `.mock`:

	mock = mocktory.mock(descriptor);

If the descriptor contains verifier keys (see below), you can also verify that all methods (with verifiers) are called as specified:

	mocktory.verify(mock);

### Mock descriptor

The mock descriptor looks like this:

	descriptor = {
		$class: <mapping to class>,
		$object: <object instance>,
		someMethod: <return value(s)>,
		someProperty: <return value(s)>
	}

Either `$class` or `$object` is required. If both are present `$object` takes precendence. `$class` maps to the MockBox `createMock` method, `$object` maps to `prepareMock`.

Any other key on the descriptor is going to be a mocked method. If no method with the same name exists, the key is assumed to match a property, and results in a mocked getter `get<key>`.

The return value can be any value. This extended example will make this clear:

	descriptor = {
		$class: "Person",					// a Person object

		// In this example we assume that the keys all map to a property and that a getter is to be mocked for each.

		id: 1,								// Single value: getId() returns the value
		birthDate: function () {			// getBirthDate() calls the function and returns its value.
			return CreateDate(1980, 1, 1);
		},
		partner: {							// Mock descriptor: getPartner() returns the mock
			$class: "Person",				// described by this descriptor
			id: 2,
			birthDate: CreateDate(1980, 10, 10)
		},
		hobbies: [							// Array of mock descriptors: getHobbies() returns
			{								// the array of mocks described by this descriptor
				$class: "Hobby",
				label: "Stamp collecting"
			},
			{
				$class: "Hobby",
				label: "Play the didgeridoo"
			}
		]
	}

### Result descriptor

Additionally, the return value can be a result descriptor or an array of result descriptors. A result descriptor is another struct with some special `$` prepended keys that are used for mocking functions and for verifying mocks. The mocking keys:

Key			| Description
---------------------------------------------------------------------------------
`$returns` 	| A (single) return value. Can be any value.
`$results`	| An array of return values, which are returned in subsequent calls.
`$callback`	| A function to be called when the mocked function is called.
`$args`		| An array of arguments to match. Only when the arguments match, does the method return the value (specified in `$returns`, `$results` or `$callback`).

Except `$returns`, which does not exist with MockBox, these keys map to the corresponding method on the mock object. `$returns` exists to differentiate
between a function that returns an array and one that iterates over values in an array.

To verify that a method is called a certain number of times, add one of the following keys to the descriptor:

Key			| Description
---------------------------------------------------------------------------------
`$times`	| Verifies that the method is called the given number of times.
`$atLeast`	| Verifies that the method is called at least the given number of times.
`$atMost`	| Verifies that the method is called at most the given number of times.
`$between`	| Verifies that the method is called between the lower and higher number of times (inclusive).

Accepted values for these keys are single numbers, and for `$between` an array of 2 values `[low, high]`.
Additionally, an array of the value(s) and a message string is allowed. See below for an example.

Mocktory uses the assertion library included with TestBox, so if an assertion fails, the test immediately fails.
The names of the keys match MockBox methods, but these methods are not used because MockBox does not
take arguments into account. With MockBox, `mock.$count("method")` returns the number of times that `method` is
called, regardless of the arguments.

Example mock descriptor with result descriptors:

	descriptor = {
		$class: "Person",
		id: {
			$returns: 1,
			$times: [1, "getId() should be called once"]
		},
		highScore: [
			{
				$args: ["Space Invaders"],
				$returns: 10000,
				$between: [2, 3, "getHighScore for Space Invaders should be called 2 or 3 times"]
			},
			{
				$args: ["Arkanoid"],
				$returns: 20000,
				$atMost: 2
			}
		]
	}

Installation
------------
Clone this repository and create a mapping to the `/src` directory, or just place Mocktory.cfc under an existing mapping.

Requirements
------------
Any CFML engine that supports member functions, the elvis operator and one or two other improvements made by Railo. ColdFusion 11
should work but I have not tested it (and don't intend to).