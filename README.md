bookshelf-fields
================

[Bookshelf plugin](https://github.com/tgriesser/bookshelf) for simpler model validation and field format convertion.

Example - coffeescript
----------------------

```coffeescript
Bookshelf = require 'bookshelf'
Fields = require 'bookshelf-fields'

db = Bookshelf.initialize
    client: 'sqlite'
    connection:
        filename: './test.db'

db.plugin Fields.plugin

Fields.polute_function_prototype()

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

        user.email = 'invalid-email' # simply calliong @set('email', 'invalid-email') in setter

        user.save().otherwise (errors) ->
            console.log errors.toJSON() # { email: 'The email must contain a valid email address' }
```

Example - coffeescript
----------------------

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

        user.email = 'invalid-email'; // simply calliong @set('email', 'invalid-email') in setter

        user.save().otherwise(function(errors) {
            console.log(errors.toJSON()); // { email: 'The email must contain a valid email address' }
        });
});
```
