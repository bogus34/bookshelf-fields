bookshelf-fields
================

[Bookshelf](https://github.com/tgriesser/bookshelf) plugin for simpler model validation and field format convertion.

* [Fields](#fields)
* [Advanced](#advanced)
* [Add custom behaviour](#custom_behaviour)
* [Examples](#examples)

## What exactly it does

First of all when plugged in with call to db.plugin it (re)defines several db.Model methods:

* validate - perform validation of model with [CheckIt](https://github.com/tgriesser/checkit). It uses instance array 'validations' for
  field-level validation and array 'model_validations' for validating the whole model.

* format/parse - for each field defined in model applys its format/parse method

Then when field is applyed to a model it

* stores the itself in the models  __meta.fields array

* may add some validation rules to validations of model_validations arrays

* defines property with the same name. By default this property only calls basic set and get
  methods. You may prevent creation of property by passing `dont_create_properties: true`
  or `create_properties: false` to Fields.plugin or as an option of the field

And finally when called to enable_validation it redefines models initialize method, adding
subscription to event 'saving' to perform validation.


## Basic usage

First you need to require bookshelf-fields and apply exported plugin to an initialized database instance:

    Fields = require 'bookshelf-fields'
    db.plugin Fields.plugin

Now you are ready to add fields information to models. There are two equivalent ways to do it: with
exported functions 'field', 'fields' and 'enable_validation' and with the same methods, mixed into a
Function prototype. If you choose the second way you need to call
`Fields.pollute_function_prototype()` before.

## Provided helpers

* `db.Checkit` - Checkit module used for validation

* `plugin(options)` - method that mixes Fields functionality into a Bookshelf Model

    `db.plugin Fields.plugin()`
    
* `enable_validation(model, options)` - actually turn on validation for a specified model. Options
  are stored in Model.prototype.validation_options and passed to Checkit when validation applied.

    `enable_validation(User)`

* `field(model, field_class, name, options)` - add field to a model

    `field(User, Fields.StringField, 'username', {max_length: 64})`

* `fields(model, field_definitions...)` - add a bunch of fields to a model. field_definitions is one
  or more arrays like [field_class, name, options]

## With [bookshelf-coffee-helpers](https://github.com/bogus34/bookshelf-coffee-helpers)

* `db.pollute_function_prototype()` - add methods `enable_validation`, `field` and `fields` to a
  Function prototype. Those methods have the same signature as a same-named functions excluding
  first 'model' parameter.

* `db.cleanup_function_prototype()` - remove methods added in `pollute_function_prototype`

## <a id="fields"></a>Fields

### Common options

* `required`: boolean - field must be provided and not empty
* `exists`: boolean - field must not be undefined
* `choices`: [array or hash] - field must have one of provided values

    `choices` may be defined as an array (`['foo', 'bar']`) or as a hash (`{foo: 'foo description', bar:
    bar description'}`). If hash used then field value is compared with hash keys.

* `comparator`: function - used with `choices` to provide custom equality checker.

    Useful if fields value is an object and simple '==' is not adequate.

* `message`: used as a default error message.

* `label`: used as a default field label and substituted to error message. Look at tgriesser/checkit for details.

### StringField

* `min_length` | `minLength`: integer
* `max_length` | `maxLength`: integer

### EmailField

StringField with simple check that value looks like a email address

### NumberField

Does no any validation - use IntField or FloatField instead!

* `gt` | `greater_than` | `greaterThan`: integer
* `gte` | `greater_than_equal_to` | `greaterThanEqualTo` | `min`: integer
* 'lt` | `less_than` | `lessThan`: integer
* `lte` | `less_than_equal_to` | `lessThanEqualTo` | `max`: integer

### IntField

NumberField checked to be Integer. Applys parseInt when loaded.

### FloatField

NumberField checked to be Float. Applys parseFloat when loaded.

### BooleanField

Casts value to Boolean on parse and format.

### DateTimeField

Validates that value is a Date or a string than can be parsed as Date.
Converts value to Date on parse and format.

### DateField

DateTimeField with stripped Time part.

### JSONField

Validates that value is object or a valid JSON string.
Parses string from JSON when loaded and stringifies to JSON when formatted.

## <a id="advanced"></a> Advanced validation

* you may assign object instead of value to validation options:

    `mix_length: {value: 10, message: '{{label}} is too short to be valid!'}`

    Additional options will be passed to checkit.

* you may add complete Checkit validation rules to field with `validations` option:

    `@field StringField 'username', validations: [{rule: 'minLength:5'}]`

## <a id="custom_behaviour"></a> Add custom behaviour

You can add extra validations to models arrays validations and model_validations. Just make sure
that you doesn't throw away validations added by fields. If you redefine initialize method call
parent initialize or manage calling validate method on model saving. You can also redefine validate
method.


## <a id="examples"></a>Examples

### coffeescript

```coffeescript
Bookshelf = require 'bookshelf'
Fields = require 'bookshelf-fields'

db = Bookshelf.initialize
    client: 'sqlite'
    connection:
        filename: './test.db'

db.plugin Fields.plugin

Fields.pollute_function_prototype()

class User extends db.Model
    tableName: 'users'

    @enable_validation()
    @field Fields.StringField, 'username', max_length: 32
    @field Fields.EmailField, 'email'

Fields.cleanup_function_prototype()

new User(username: 'bogus', email: 'bogus@test.com').save()
    .otherwise (errors) ->
        console.log errors.toJSON()
        throw errors
    .then (user) ->
        console.log user.id
        console.log user.username # username is a property, calling @get('username') in getter
        console.log user.email

        user.email = 'invalid-email' # calls @set('email', 'invalid-email') in setter

        user.save().otherwise (errors) ->
            console.log errors.toJSON() # { email: 'The email must contain a valid email address' }
```

###javascript


```javascript
Bookshelf = require('bookshelf');
Fields = require('bookshelf-fields');

var db = Bookshelf.initialize({
    client: 'sqlite',
    connection: { filename: './test.db' }
});

db.plugin(Fields.plugin);

User = db.Model.extend({ tableName: 'users' });
Fields.enable_validation(User);

Fields.fields(User,
    [Fields.StringField, 'username', {max_length: 32}],
    [Fields.EmailField, 'email']
);

new User({username: 'bogus', email: 'bogus@test.com'}).save()
    .otherwise(function(errors) {
        console.log(errors.toJSON());
        throw errors;
    }).then(function(user) {
        console.log(user.id);
        console.log(user.username); // username is a property, calling @get('username') in getter
        console.log(user.email);

        user.email = 'invalid-email'; // calls @set('email', 'invalid-email') in setter

        user.save().otherwise(function(errors) {
            console.log(errors.toJSON()); // { email: 'The email must contain a valid email address' }
        });
});
```
