knex = require 'knex'
Bookshelf = require 'bookshelf'
F = require '../src/bookshelf-fields'
When = require 'when'

describe "Bookshelf fields", ->
    this.timeout 3000
    db = null
    User = Users = null

    define_model = (fields...) ->
        class User extends db.Model
            tableName: 'users'
            @enable_validation()
            @fields fields...

    before ->
        db_variant = process.env.BOOKSHELF_FIELDS_TESTS_DB_VARIANT
        db_variant ?= 'sqlite'

        switch db_variant
            when 'sqlite'
                db = Bookshelf knex
                    client: 'sqlite'
                    debug: process.env.BOOKSHELF_FIELDS_TESTS_DEBUG?
                    connection:
                        filename: ':memory:'
            when 'pg', 'postgres'
                db = Bookshelf knex
                    client: 'pg'
                    debug: process.env.BOOKSHELF_FIELDS_TESTS_DEBUG?
                    connection:
                        host: '127.0.0.1'
                        user: 'test'
                        password: 'test'
                        database: 'test'
                        charset: 'utf8'
            else throw new Error "Unknown db variant: #{db_variant}"
        db.plugin require 'bookshelf-coffee-helpers'
        db.plugin F.plugin()
        knex = db.knex
        knex.schema.dropTableIfExists('users')
            .then ->
                knex.schema.createTable 'users', (table) ->
                    table.increments('id').primary()
                    table.string 'username', 255
                    table.string 'email', 255
                    table.float 'code'
                    table.boolean 'flag'
                    table.dateTime 'last_login'
                    table.date 'birth_date'
                    table.json 'additional_data'

    describe 'common behaviour', ->
        beforeEach ->
            db.pollute_function_prototype()
            User = define_model \
                [F.StringField, 'username', min_length: 3, max_length: 15],
                [F.EmailField, 'email']

        afterEach ->
            db.cleanup_function_prototype()

        it 'should create array of validations', ->
            User::validations.should.deep.equal
                username: ['minLength:3', 'maxLength:15']
                email: ['email']

        it 'should run validations', ->
            validation_called = false
            f = ->
                validation_called = true
                false
            User::validations.username.push f

            new User(username: 'bogus').save()
                .then ->
                    done new Error('then called instead of otherwise')
                .otherwise (e) ->
                    validation_called.should.be.true

        it 'should run validations w/o save', ->
            When.all [
                new User(username: 'bogus').validate().should.be.fulfilled
                new User(username: 'bogus', email: 'foobar').validate().should.be.rejected
            ]

        it 'should perserve custom validations', ->
            f = ->
            User = class User extends db.Model
                tableName: 'users'
                validations: {
                    username: [f]
                }
                model_validations: [f]
                @enable_validation()
                @field F.StringField, 'username', min_length: 3, exists: true

            User::validations.should.deep.equal {username: [f, 'exists', 'minLength:3']}
            User::model_validations[0].should.equal f

        it 'doesn\'t add properties if initialized with {create_properties: false}', ->
            db2 = Bookshelf.initialize
                client: 'sqlite'
                connection:
                    filename: ':memory:'

            db2.plugin F.plugin(create_properties: false)

            class User extends db2.Model
                tableName: 'users'
                @field F.StringField, 'username'

            expect((new User(username: 'foo')).username).to.be.undefined

        it 'doesn\'t add property if field has option {create_property: false}', ->
            class User extends db.Model
                tableName: 'users'
                @field F.StringField, 'username', create_property: false

            expect((new User(username: 'foo')).username).to.be.undefined

        it 'doesn\'t overwrite existing methods and properties', ->
            class User extends db.Model
                tableName: 'users'
                @field F.StringField, 'query'

            new User().query.should.be.a 'function'

        it 'field named "id" doesnt overwrite internal id property', ->
            class User extends db.Model
                tableName: 'users'
                @field F.StringField, 'id'

            new User(id: 1).id.should.equal 1


    describe 'Common options', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'validates fields presense', ->
            User = define_model \
                    [F.Field, 'username', exists: true],
                    [F.Field, 'email', required: true]

            attempts = [
                new User(username: 'foo', email: 'bar').validate().should.be.fulfilled
                new User(username: '', email: 'bar').validate().should.be.fulfilled
                new User(email: 'bar').validate().should.be.rejected
                new User(username: 'foo', email: '').validate().should.be.rejected
                new User(username: 'foo', email: null).validate().should.be.rejected
            ]

            When.all(attempts)

        describe 'can use choices', ->
            it 'with choices defined as array', ->
                available_names = ['foo', 'bar']
                User = define_model [F.StringField, 'username', choices: available_names]
                attempts = [
                    new User(username: 'foo').validate().should.be.fulfilled
                    new User(username: 'noon').validate().should.be.rejected
                ]
                When.all(attempts)
            it 'with custom equality checker', ->
                available_names = [
                    {name: 'foo'}
                    {name: 'bar'}
                ]
                class CustomField extends F.StringField
                    format: (attrs) ->
                        attrs[@name] = attrs[@name].name if @name of attrs
                comparator = (a, b) ->
                    a.name == b.name
                User = define_model [CustomField, 'username', choices: available_names, comparator: comparator]
                attempts = [
                    new User(username: {name: 'foo'}).validate().should.be.fulfilled
                    new User(username: {name: 'noon'}).validate().should.be.rejected
                ]
                When.all(attempts)

        it 'accepts custom validation rules like Checkit do', ->
            User = define_model [
                F.StringField, 'username', validations: [{rule: 'minLength:5', message: '{{label}}: foo', label: 'foo'}]
            ]

            new User(username: 'bar').validate()
                .then -> throw 'Should be rejected'
                .catch (e) -> e.get('username').message.should.equal 'foo: foo'

    describe 'StringField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'validates min_length and max_length', ->
            User = define_model [F.StringField, 'username', min_length: 5, max_length: 10]

            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

            attempts = [
                new User(username: 'foo').validate().should.be.rejected
                new User(username: 'Some nickname that is longer then 10 characters').validate().should.be.rejected
                new User(username: 'justfine').validate().should.be.fulfilled
            ]

            When.all(attempts)

        it 'uses additional names for length restrictions', ->
            User = define_model [F.StringField, 'username', minLength: 5, maxLength: 10]
            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

    describe 'EmailField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'validates email', ->
            User = define_model [F.EmailField, 'email']
            User::validations.email.should.deep.equal ['email']

            attempts = [
                new User(email: 'foo').validate().should.be.rejected
                new User(email: 'foo@bar.com').validate().should.be.fulfilled
            ]

            When.all(attempts)

    describe 'IntField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'validates integers', ->
            User = define_model [F.IntField, 'code']
            User::validations.code.should.deep.equal ['integer']

            attempts = [
                new User(code: 'foo').validate().should.be.rejected
                new User(code: '10foo').validate().should.be.rejected
                new User(code: 10.5).validate().should.be.rejected
                new User(code: 10).validate().should.be.fulfilled
                new User(code: '10').validate().should.be.fulfilled
                new User(code: '-10').validate().should.be.fulfilled
            ]

            When.all(attempts)

        it 'validates natural', ->
            User = define_model [F.IntField, 'code', natural: true]
            User::validations.code.should.deep.equal ['integer', 'natural']

            attempts = [
                new User(code: 10).validate().should.be.fulfilled
                new User(code: -10).validate().should.be.rejected
                new User(code: '-10').validate().should.be.rejected
            ]

            When.all(attempts)

        it 'validates bounds', ->
            User = define_model [F.IntField, 'code', greater_than: 1, less_than: 10]
            User::validations.code.should.deep.equal ['integer', 'greaterThan:1', 'lessThan:10']

            attempts = [
                new User(code: 5).validate().should.be.fulfilled
                new User(code: 1).validate().should.be.rejected
                new User(code: 10).validate().should.be.rejected
            ]

            When.all(attempts)

    describe 'FloatField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'validates floats', ->
            User = define_model [F.FloatField, 'code']
            User::validations.code.should.deep.equal ['isNumeric']

            attempts = [
                new User(code: 'foo').validate().should.be.rejected
                new User(code: '10foo').validate().should.be.rejected
                new User(code: 10.5).validate().should.be.fulfilled
                new User(code: 10).validate().should.be.fulfilled
                new User(code: '10.5').validate().should.be.fulfilled
                new User(code: '-10.5').validate().should.be.fulfilled
            ]

            When.all(attempts)
    describe 'BooleanField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'stores boolean values', ->
            User = define_model [F.BooleanField, 'flag']
            new User(flag: 'some string').save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.flag.should.be.true

    describe 'DateTimeField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'stores Date objects', ->
            User = define_model [F.DateTimeField, 'last_login']
            date = new Date('2013-09-25T15:00:00.000Z')
            new User(last_login: date).save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.last_login.should.be.an.instanceof Date
                            user.last_login.toISOString().should.equal date.toISOString()

        it 'validates date', ->
            User = define_model [F.DateTimeField, 'last_login']

            attempts = [
                new User(last_login: new Date()).validate().should.be.fulfilled
                new User(last_login: new Date().toUTCString()).validate().should.be.fulfilled
                new User(last_login: '1/1/1').validate().should.be.fulfilled
                new User(last_login: 'foobar').validate().should.be.rejected
            ]

            When.all(attempts)

    describe 'DateField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        truncate_date = (d) -> new Date(d.getFullYear(), d.getMonth(), d.getDate())

        it 'stores Date objects', ->
            User = define_model [F.DateField, 'birth_date']
            date = new Date('2013-09-25T15:00:00.000Z')
            new User(birth_date: date).save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.birth_date.should.be.an.instanceof Date
                            user.birth_date.toISOString().should.equal truncate_date(date).toISOString()

        it 'validates date', ->
            User = define_model [F.DateTimeField, 'birth_date']

            attempts = [
                new User(birth_date: new Date()).validate().should.be.fulfilled
                new User(birth_date: new Date().toUTCString()).validate().should.be.fulfilled
                new User(birth_date: '1/1/1').validate().should.be.fulfilled
                new User(birth_date: 'foobar').validate().should.be.rejected
            ]

            When.all(attempts)

    describe 'JSONField', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
            db.knex('users').truncate()

        it 'stores JSON objects', ->
            User = define_model [F.JSONField, 'additional_data']

            data  =
                nickname: 'bogus'
                interests: ['nodejs', 'photography', 'tourism']

            new User(additional_data: data).save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.additional_data.should.deep.equal data

        it 'validates JSON', ->
            User = define_model [F.JSONField, 'additional_data']

            attempts = [
                new User(additional_data: {foo: 'bar'}).validate().should.be.fulfilled
                new User(additional_data: JSON.stringify(foo: 'bar')).validate().should.be.fulfilled
                new User(additional_data: 42).validate().should.be.rejected
                new User(additional_data: 'not a json').validate().should.be.rejected
            ]

            When.all(attempts)

    describe 'Custom error messages', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()

        it 'uses provided messages', ->
            User = define_model \
                [F.StringField, 'foo', min_length: {value: 10, message: 'foo'}]

            new User(foo: 'bar').validate().should.be.rejected
                .then (e) ->
                    e.get('foo').message.should.equal 'foo'

        it 'uses field default error message and label', ->
            User = define_model \
                [F.StringField, 'username', min_length: 10, message: '{{label}}: foo', label: 'foo']

            new User(username: 'bar').validate().should.be.rejected
                .then (e) ->
                    e.get('username').message.should.equal 'foo: foo'

        it 'user field error message and label for field type validation', ->
            User = define_model \
                [F.EmailField, 'email', message: '{{label}}: foo', label: 'foo']

            new User(email: 'bar').validate().should.be.rejected
                .then (e) ->
                    e.get('email').message.should.equal 'foo: foo'

        it 'can use i18n for messages', ->
            db.Checkit.i18n.ru =
                labels: {}
                messages:
                    email: 'Поле {{label}} должно содержать email-адрес'

            class User extends db.Model
                tableName: 'users'
                @enable_validation(language: 'ru')
                @field F.EmailField, 'email'

            new User(email: 'bar').validate().should.be.rejected
                .then (e) ->
                    e.get('email').message.should.equal 'Поле email должно содержать email-адрес'
