import testbox.system.Assertion;
import testbox.system.MockBox;

/**
 * A 'DSL' for quickly setting up mocks using MockBox.
 */
component {

	this.mockKeys = ["$object", "$class", "$interface"];
	this.resultKeys = ["$results", "$callback", "$returns", "$args"];
	// Struct of comparisons and numbers of arguments.
	this.comparisons = {
		$times: 1,
		$atLeast: 1,
		$atMost: 1,
		$between: 2
	}

	public void function init(required MockBox mockFactory, Function expand) {
		this.mockFactory = arguments.mockFactory;
		this.assert = new Assertion();
		this.expand = arguments.expand ?: function (name) {
			return arguments.name;
		}
	}

	public Any function mock(required Any descriptor) {

		if (IsSimpleValue(arguments.descriptor)) {
			// Descriptor is a string with a class mapping.
			return this.mock({
				$class: this.expand(arguments.descriptor)
			});
		} else if (IsObject(arguments.descriptor)) {
			return this.mock({
				$object: arguments.descriptor
			});
		}

		// The descriptor must be a mock descriptor.
		if (!this.isMockDescriptor(arguments.descriptor)) {
			Throw("Invalid mock descriptor", "IllegalArgumentException", "A mock descriptor has at least one of the following keys: " & this.mockKeys.toList(", "));
		}

		var mockDescriptor = normalize(arguments.descriptor);

		var object = mockDescriptor.keyExists("$object") ?
			// If the object is already a mock, don't mock again.
			StructKeyExists(mockDescriptor.$object, "mockBox") ? mockDescriptor.$object : this.mockFactory.prepareMock(mockDescriptor.$object) :
			mockDescriptor.keyExists("$class") ? this.mockFactory.createMock(this.expand(mockDescriptor.$class)) :
			this.mockFactory.createStub(implements = this.expand(mockDescriptor.$interface));

		// Mock functions.
		for (var key in mockDescriptor) {
			if (!this.isMockKey(key)) {
				// Find out if this is a function or a property (where we assume a getter has to be mocked).
				var functionName = this.isFunction(object, key) ? key : "get" & key;
				for (var resultDescriptor in mockDescriptor[key]) {
					this.mockFunction(object, functionName, resultDescriptor);
				}
			}
		}

		// Append the current descriptor if the object was mocked earlier.
		if (!StructKeyExists(object, "_mockDescriptor")) {
			mockDescriptor.$object = object;
			object._mockDescriptor = mockDescriptor;
		} else {
			for (var key in mockDescriptor) {
				if (!this.isMockKey(key)) {
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
		return !IsObject(arguments.descriptor) && arguments.descriptor.some(function (key) {
			return this.isMockKey(arguments.key);
		});
	}

	public Boolean function isResultDescriptor(required Struct descriptor) {
		return !IsObject(arguments.descriptor) && arguments.descriptor.some(function (key) {
			return this.isResultKey(arguments.key);
		});
	}

	private Boolean function isMockKey(required String key) {
		return this.mockKeys.find(arguments.key) > 0;
	}

	private Boolean function isResultKey(required String key) {
		return this.resultKeys.find(arguments.key) > 0;
	}

	private Boolean function isFunction(required Any object, required String name) {
		return GetMetadata(arguments.object).findKey("functions", "all").some(function (result) {
			// Each result has a value key that contains an array of function metadata structs.
			return arguments.result.value.some(function (metadata) {
				return arguments.metadata.name == name;
			});
		});
	}

	/**
	 * Returns a copy of the mock descriptor where all keys have an array of result descriptors.
	 */
	private Struct function normalize(required Struct descriptor) {

		// Make a shallow copy of the descriptor. We don't want to duplicate objects.
		var mockDescriptor = Duplicate(arguments.descriptor, false);

		for (var key in mockDescriptor) {
			if (!this.isMockKey(key)) {
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
					descriptors.append({$returns: JavaCast("null", 0)});
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
				} else if (IsCustomFunction(result) || IsClosure(result)) {
					descriptors.append({$callback: result});
				} else {
					// It's a value of some other type.
					descriptors.append({$returns: result});
				}

				// Overwrite the key.
				mockDescriptor[key] = descriptors.map(function (descriptor) {
					// Convert comparison values to arrays (if necessary) and make sure the last item is a message.
					// We need to make a shallow copy of the result descriptor, because this one was not
					local.descriptor = Duplicate(arguments.descriptor, false);
					this.comparisons.each(function (comparison, count) {
						if (descriptor.keyExists(arguments.comparison)) {
							var value = descriptor[arguments.comparison];
							if (!IsArray(value)) {
								// Only $times, $atLeast and $atMost.
								descriptor[arguments.comparison] = [value, ""];
							} else if (value.len() <= arguments.count) {
								descriptor[arguments.comparison].append("");
							}
						}
					});

					return descriptor;
				});

			}
		}

		return mockDescriptor;
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
			// $returns may or may not exist, and may or may not contain null.
			arguments.object.$results(arguments.descriptor.$returns ?: JavaCast("null", 0));
		}

	}

	public void function verify(required Any mockObject, Struct descriptor) {

		var mockDescriptor = IsNull(arguments.descriptor) ? arguments.mockObject._mockDescriptor : this.normalize(arguments.descriptor);

		for (var key in mockDescriptor) {
			if (!this.isMockKey(key)) {
				// All keys have an array of result descriptors.
				for (var descriptor in mockDescriptor[key]) {
					var functionName = this.isFunction(arguments.mockObject, key) ? key : "get" & key;
					// Test for existence of one of the comparison types. The values are arrays of comparison values and messages.
					for (var comparison in ["$times", "$atLeast", "$atMost", "$between"]) {
						if (descriptor.keyExists(comparison)) {
							var count = this.callCount(arguments.mockObject, functionName, descriptor.$args ?: NullValue());
							if (comparison == "$times") {
								this.assert.isEqual(descriptor.$times[1], count, descriptor.$times[2]);
							} else if (comparison == "$atLeast") {
								// The isGTE, isLTE and between assertions have the actual value is their first argument.
								this.assert.isGTE(count, descriptor.$atLeast[1], descriptor.$atLeast[2]);
							} else if (comparison == "$atMost") {
								this.assert.isLTE(count, descriptor.$atMost[1], descriptor.$atMost[2]);
							} else if (comparison == "$between") {
								this.assert.between(count, descriptor.$between[1], descriptor.$between[2], descriptor.$between[3]);
							}

							break;
						}
					}
				}
			}
		}

	}

	public Numeric function callCount(required Any mockObject, required String methodName, Any args) {

		var callLog = arguments.mockObject.$callLog();

		// The $ methods on the mock, as generated by MockBox, don't take arguments into account.
		if (!callLog.keyExists(arguments.methodName)) {
			return 0;
		}

		var calls = callLog[arguments.methodName];
		// Calls is an array of argument scopes.
		return calls.reduce(function (count, callArgs) {
			if (IsNull(args)) {
				// No arguments specified, so just count calls.
				return arguments.count + 1;
			} else if (args.len() == arguments.callArgs.len()) {
				if (args.every(function (value, index) {
					return this.isEqual(arguments.value, callArgs[arguments.index]);
				})) {
					return arguments.count + 1;
				}
			}

			return arguments.count;
		}, 0);
	}

	public Boolean function isEqual(required Any value1, required Any value2) {

		local.value1 = arguments.value1;
		local.value2 = arguments.value2;

		if (IsSimpleValue(value1) && IsSimpleValue(value2)) {

			return value1 == value2;

		} else if (IsObject(value1) && IsObject(value2)) {

			var system = CreateObject("java", "java.lang.System");
			return system.identityHashCode(value1) == system.identityHashCode(value2);

		} else if (IsStruct(value1) && IsStruct(value2)) {

			return value1.len() == value2.len() && value1.every(function (key) {
				return value2.keyExists(arguments.key) && 	this.isEqual(value1[arguments.key], value2[arguments.key]);
			});

		} else if (IsArray(value1) && IsArray(value2)) {

			return value1.len() == value2.len() && value1.every(function (_, index) {
				return this.isEqual(value1[arguments.index], value2[arguments.index]);
			});

		} else if (IsQuery(value1) && IsQuery(value2)) {

			if (value1.recordCount() == value2.recordCount() && value1.columnList() == value2.columnList()) {
				return Compare(SerializeJSON(value1), SerializeJSON(value2)) == 0;
			}

		} else if (IsXMLDoc(value1) && IsXMLDoc(value2) || IsXMLElem(value1) && IsXMLElem(value2)) {

			return ToString(value1) == ToString(value2);

		}

		return false;
	}

}