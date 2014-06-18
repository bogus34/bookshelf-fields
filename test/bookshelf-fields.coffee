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
                db = Bookshelf.initialize
                    client: 'sqlite'
                    debug: process.env.BOOKSHELF_FIELDS_TESTS_DEBUG?
                    connection:
                        filename: ':memory:'
            when 'pg', 'postgres'
                db = Bookshelf.initialize
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
                new User(username: 'foo', email: 'bar').save().should.be.fulfilled
                new User(username: '', email: 'bar').save().should.be.fulfilled
                new User(email: 'bar').save().should.be.rejected
                new User(username: 'foo', email: '').save().should.be.rejected
                new User(username: 'foo', email: null).save().should.be.rejected
            ]

            When.all(attempts)

        describe 'can use choices', ->
            it 'with choices defined as array', ->
                available_names = ['foo', 'bar']
                User = define_model [F.StringField, 'username', choices: available_names]
                attempts = [
                    new User(username: 'foo').save().should.be.fulfilled
                    new User(username: 'noon').save().should.be.rejected
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
                    new User(username: {name: 'foo'}).save().should.be.fulfilled
                    new User(username: {name: 'noon'}).save().should.be.rejected
                ]
                When.all(attempts)

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
                new User(username: 'foo').save().should.be.rejected
                new User(username: 'Some nickname that is longer then 10 characters').save().should.be.rejected
                new User(username: 'justfine').save().should.be.fulfilled
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
                new User(email: 'foo').save().should.be.rejected
                new User(email: 'foo@bar.com').save().should.be.fulfilled
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
                new User(code: 'foo').save().should.be.rejected
                new User(code: '10foo').save().should.be.rejected
                new User(code: 10.5).save().should.be.rejected
                new User(code: 10).save().should.be.fulfilled
                new User(code: '10').save().should.be.fulfilled
                new User(code: '-10').save().should.be.fulfilled
            ]

            When.all(attempts)

        it 'validates natural', ->
            User = define_model [F.IntField, 'code', natural: true]
            User::validations.code.should.deep.equal ['integer', 'natural']

            attempts = [
                new User(code: 10).save().should.be.fulfilled
                new User(code: -10).save().should.be.rejected
                new User(code: '-10').save().should.be.rejected
            ]

            When.all(attempts)

        it 'validates bounds', ->
            User = define_model [F.IntField, 'code', greater_than: 1, less_than: 10]
            User::validations.code.should.deep.equal ['integer', 'greaterThan:1', 'lessThan:10']

            attempts = [
                new User(code: 5).save().should.be.fulfilled
                new User(code: 1).save().should.be.rejected
                new User(code: 10).save().should.be.rejected
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
                new User(code: 'foo').save().should.be.rejected
                new User(code: '10foo').save().should.be.rejected
                new User(code: 10.5).save().should.be.fulfilled
                new User(code: 10).save().should.be.fulfilled
                new User(code: '10.5').save().should.be.fulfilled
                new User(code: '-10.5').save().should.be.fulfilled
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
                new User(last_login: new Date()).save().should.be.fulfilled
                new User(last_login: new Date().toUTCString()).save().should.be.fulfilled
                new User(last_login: '1/1/1').save().should.be.fulfilled
                new User(last_login: 'foobar').save().should.be.rejected
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
                new User(birth_date: new Date()).save().should.be.fulfilled
                new User(birth_date: new Date().toUTCString()).save().should.be.fulfilled
                new User(birth_date: '1/1/1').save().should.be.fulfilled
                new User(birth_date: 'foobar').save().should.be.rejected
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
                new User(additional_data: {foo: 'bar'}).save().should.be.fulfilled
                new User(additional_data: JSON.stringify(foo: 'bar')).save().should.be.fulfilled
                new User(additional_data: 42).save().should.be.rejected
                new User(additional_data: 'not a json').save().should.be.rejected
            ]

            When.all(attempts)

    describe 'custom error messages', ->
        before ->
            db.pollute_function_prototype()
        after ->
            db.cleanup_function_prototype()
        it 'uses provided messages', ->
            User = define_model \
                [F.StringField, 'foo', min_length: {value: 10, message: 'foo'}]

            promise = new User(foo: 'bar').validate()
            promise.should.be.rejected
            promise.catch (e) ->
                e.get('foo').message.should.equal 'foo'
