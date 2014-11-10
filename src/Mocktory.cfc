import testbox.system.Assertion;
import testbox.system.MockBox;

/**
* A 'DSL' for quickly setting up mocks using MockBox.
*/
component {

	// Struct of comparisons and numbers of arguments.
	this.comparisons = {
		$times: 1,
		$atLeast: 1,
		$atMost: 1,
		$between: 2
	}

	public void function init(required MockBox mockFactory) {
		this.mockFactory = arguments.mockFactory;
		this.assert = new Assertion();
	}

	public Any function mock(required Struct descriptor) {

		var mockDescriptor = Duplicate(arguments.descriptor, false); // Make a shallow copy of the descriptor.
		// The descriptor must be a mock descriptor.
		if (!this.isMockDescriptor(mockDescriptor)) {
			Throw("Invalid mock descriptor", "IllegalArgumentException", "A mock descriptor has at least a $class or $object key.");
		}

		var object = mockDescriptor.keyExists("$object") ?
			// If the object is already a mock, don't mock again.
			StructKeyExists(mockDescriptor.$object, "mockBox") ? mockDescriptor.$object : this.mockFactory.prepareMock(mockDescriptor.$object) :
			this.mockFactory.createMock(mockDescriptor.$class);

		for (var key in mockDescriptor) {
			if (key != "$object" && key != "$class") {
				/*
					Determine the value to be returned from the mocked function.
					We have the following cases:
					- struct:
						- result descriptor: return the result as described
						- mock descriptor: return the mock
						- return the struct as is
					- array:
						- array of result descriptors: return the result corresponding to the call (arguments)
						- array of mock descriptors: return the array of mocks
						- return the array as is
					- other values: return the value as is
				*/
				var result = mockDescriptor[key] ?: JavaCast("null", 0);
				var descriptors = []; // Array of result descriptors for this function (will have length 1 in all except 1 case).
				if (IsNull(result)) {
					descriptors.append({$returns: JavaCast("null", 0)})
				} else if (IsStruct(result)) {
					if (this.isResultDescriptor(result)) {
						descriptors.append(result);
					} else {
						var value = this.isMockDescriptor(result) ? this.mock(result) : result;
						descriptors.append({$returns: value});
					}
				} else if (IsArray(result)) {
					if (!result.isEmpty()) {
						// Just check the first element. If it is some descriptor we assume all of them are of the same type.
						if (IsStruct(result[1])) {
							if (this.isResultDescriptor(result[1])) {
								// An array of result descriptors maps to the mocking of multiple calls (different sets of arguments).
								descriptors = result;
							} else if (this.isMockDescriptor(result[1])) {
								// Return an array of mock objects.
								descriptors.append({
									$returns: result.map(function (descriptor) {
										return this.mock(arguments.descriptor);
									})
								});
							} else {
								// Array of regular structs (or things that look like structs).
								descriptors.append({$returns: result});
							}
						} else {
							// The array contains something else.
							descriptors.append({$returns: result});
						}
					} else {
						// Empty array.
						descriptors.append({$returns: result});
					}
				} else {
					// It's a value of some other type.
					descriptors.append({$returns: result});
				}

				// Find out if this is a function or a property (where we assume a getter has to be mocked).
				var functionName = this.isFunction(object, key) ? key : "get" & key;

				// Overwrite the key, so that we always have an array of result descriptors.
				mockDescriptor[key] = descriptors.map(function (descriptor) {
					// Convert comparison values to arrays (if necessary) and make sure the last item is a message.
					local.descriptor = Duplicate(arguments.descriptor, false);
					this.comparisons.each(function (comparison, count) {
						if (descriptor.keyExists(arguments.comparison)) {
							var value = descriptor[arguments.comparison];
							if (!IsArray(value)) {
								descriptor[arguments.comparison] = [value, ""];
							} else if (value.len() <= arguments.count) {
								descriptor[arguments.comparison].append("");
							}
						}
					});
					// Mock the function.
					this.mockFunction(object, functionName, arguments.descriptor);

					return descriptor;
				});

			}
		}

		// Append the current descriptor if the object was mocked earlier.
		if (!StructKeyExists(object, "_mockDescriptor")) {
			object._mockDescriptor = mockDescriptor;
		} else {
			for (var key in mockDescriptor) {
				if (key != "$class" && key != "$object") {
					if (!object._mockDescriptor.keyExists(key)) {
						object._mockDescriptor[key] = mockDescriptor[key];
					} else {
						// Merge with the existing array of result descriptors.
						object._mockDescriptor[key].append(mockDescriptor[key], true);
					}
				}
			}
		}

		return object;
	}

	public Boolean function isMockDescriptor(required Struct descriptor) {
		return !IsObject(arguments.descriptor) && (arguments.descriptor.keyExists("$object") || arguments.descriptor.keyExists("$class"));
	}

	public Boolean function isResultDescriptor(required Struct descriptor) {
		// We want to be able to return null, so we can't use StructKeyExists for $returns.
		return !IsObject(arguments.descriptor) && (arguments.descriptor.keyExists("$results") || arguments.descriptor.keyExists("$callback") || arguments.descriptor.keyArray().find("$returns") > 0);
	}

	private Boolean function isFunction(required Any object, required String name) {
		// Using StructKeyExists will invoke the function if invokeImplicitAccessor = true. That would increase the call count.
		return StructKeyArray(arguments.object).findNoCase(arguments.name) > 0 && IsCustomFunction(object[arguments.name]);
	}

	private void function mockFunction(required Any object, required String name, required Struct descriptor) {

		arguments.object.$(arguments.name, JavaCast("null", 0), false);

		if (arguments.descriptor.keyExists("$args")) {
			arguments.object.$args(argumentCollection = arguments.descriptor.$args);
		}

		if (arguments.descriptor.keyExists("$results")) {
			arguments.object.$results(argumentCollection = arguments.descriptor.$results);
		} else if (arguments.descriptor.keyExists("$callback")) {
			arguments.object.$callback(arguments.descriptor.$callback);
		} else {
			// $returns exists, but may contain null.
			arguments.object.$results(arguments.descriptor.$returns ?: JavaCast("null", 0));
		}

	}

	public void function verify(required Any mockObject) {

		var mockDescriptor = arguments.mockObject._mockDescriptor;
		var callLog = arguments.mockObject.$callLog();

		for (var key in mockDescriptor) {
			if (key != "$object" && key != "$class") {
				// All keys have an array of result descriptors.
				local.mockObject = arguments.mockObject;
				mockDescriptor[key].each(function (descriptor) {
					var functionName = this.isFunction(mockObject, key) ? key : "get" & key;
					var count = this.callCount(callLog, functionName, arguments.descriptor.$args ?: []);
					// Test for existence of one of the comparison types. The values are arrays of comparison values and messages.
					if (arguments.descriptor.keyExists("$times")) {
						assert.isEqual(arguments.descriptor.$times[1], count, arguments.descriptor.$times[2]);
					} else if (arguments.descriptor.keyExists("$atLeast")) {
						// The isGTE, isLTE and between assertions have the actual value is their first argument.
						assert.isGTE(count, arguments.descriptor.$atLeast[1], arguments.descriptor.$atLeast[2]);
					} else if (arguments.descriptor.keyExists("$atMost")) {
						assert.isLTE(count, arguments.descriptor.$atMost[1], arguments.descriptor.$atMost[2]);
					} else if (arguments.descriptor.keyExists("$between")) {
						assert.between(count, arguments.descriptor.$between[1], arguments.descriptor.$between[2], arguments.descriptor.$between[3]);
					}
				});
			}
		}

	}

	private Numeric function callCount(required Struct callLog, required String methodName, required Array args) {
		// The $ methods on the mock, as generated by MockBox, don't take arguments into account.
		if (!arguments.callLog.keyExists(arguments.methodName)) {
			return 0;
		}

		var calls = arguments.callLog[arguments.methodName];
		// Calls is an array of argument scopes.
		local.args = arguments.args;
		return calls.reduce(function (count, callArgs) {
			if (args.len() == arguments.callArgs.len()) {
				local.callArgs = arguments.callArgs;
				if (args.every(function (value, index) {
					// Object equality. Probably not supported in ColdFusion.
					return arguments.value === callArgs[index];
				})) {
					return arguments.count + 1;
				}
			}

			return arguments.count;
		}, 0);
	}

}