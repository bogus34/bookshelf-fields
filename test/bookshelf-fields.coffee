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

    before (done) ->
        db_variant = process.env.BOOKSHELF_FIELDS_TESTS_DB_VARIANT
        db_variant ?= 'sqlite'

        switch db_variant
            when 'sqlite'
                db = Bookshelf.initialize
                    client: 'sqlite'
                    debug: not process.env.BOOKSHELF_FIELDS_TESTS_QUIET?
                    connection:
                        filename: ':memory:'
            when 'pg', 'postgres'
                db = Bookshelf.initialize
                    client: 'pg'
                    debug: not process.env.BOOKSHELF_FIELDS_TESTS_QUIET?
                    connection:
                        host: '127.0.0.1'
                        user: 'test'
                        password: 'test'
                        database: 'test'
                        charset: 'utf8'
            else throw new Error "Unknown db variant: #{db_variant}"
        db.plugin F.plugin
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
                .then ->
                    done()
                .otherwise (errors) ->
                    console.log errors
                    throw errors

    describe 'common behaviour', ->
        beforeEach ->
            F.pollute_function_prototype()
            User = define_model \
                [F.StringField, 'username', min_length: 3, max_length: 15],
                [F.EmailField, 'email']
            F.cleanup_function_prototype()

        it 'should create array of validations', ->
            User::validations.should.deep.equal
                username: ['minLength:3', 'maxLength:15']
                email: ['validEmail']

        it 'should run validations', (done) ->
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
                    done()
                .otherwise (e) ->
                    done e

    describe 'Common options', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates fields presense', (done) ->
            User = define_model \
                    [F.Field, 'username', nullable: false],
                    [F.Field, 'email', required: true]

            attempts = [
                new User(username: 'foo', email: 'bar').save().should.be.fulfilled
                new User(username: '', email: 'bar').save().should.be.fulfilled
                new User(username: null, email: 'bar').save().should.be.rejected
                new User(username: 'foo', email: '').save().should.be.rejected
                new User(username: 'foo', email: null).save().should.be.rejected
            ]

            When.all(attempts).should.notify done

        describe 'can use choices', ->
            it 'with choices defined as array', (done) ->
                available_names = ['foo', 'bar']
                User = define_model [F.StringField, 'username', choices: available_names]
                attempts = [
                    new User(username: 'foo').save().should.be.fulfilled
                    new User(username: 'noon').save().should.be.rejected
                ]
                When.all(attempts).should.notify done
            it 'with choices defined as hash', (done) ->
                available_names =
                    foo: 'Foo name'
                    bar: 'Bar name'
                User = define_model [F.StringField, 'username', choices: available_names]
                attempts = [
                    new User(username: 'foo').save().should.be.fulfilled
                    new User(username: 'noon').save().should.be.rejected
                ]
                When.all(attempts).should.notify done
            it 'with custom equality checker', (done) ->
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
                When.all(attempts).should.notify done

    describe 'StringField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates min_length and max_length', (done) ->
            User = define_model [F.StringField, 'username', min_length: 5, max_length: 10]

            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

            attempts = [
                new User(username: 'foo').save().should.be.rejected
                new User(username: 'Some nickname that is longer then 10 characters').save().should.be.rejected
                new User(username: 'justfine').save().should.be.fulfilled
            ]

            When.all(attempts).should.notify done

        it 'uses additional names for length restrictions', ->
            User = define_model [F.StringField, 'username', minLength: 5, maxLength: 10]
            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

    describe 'EmailField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates email', (done) ->
            User = define_model [F.EmailField, 'email']
            User::validations.email.should.deep.equal ['validEmail']

            attempts = [
                new User(email: 'foo').save().should.be.rejected
                new User(email: 'foo@bar.com').save().should.be.fulfilled
            ]

            When.all(attempts).should.notify done

    describe 'IntField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates integers', (done) ->
            User = define_model [F.IntField, 'code']
            User::validations.code.should.deep.equal ['isInteger']

            attempts = [
                new User(code: 'foo').save().should.be.rejected
                new User(code: '10foo').save().should.be.rejected
                new User(code: 10.5).save().should.be.rejected
                new User(code: 10).save().should.be.fulfilled
                new User(code: '10').save().should.be.fulfilled
                new User(code: '-10').save().should.be.fulfilled
            ]

            When.all(attempts).should.notify done

        it 'validates natural', (done) ->
            User = define_model [F.IntField, 'code', positive: true]
            User::validations.code.should.deep.equal ['isInteger', 'isPositive']

            attempts = [
                new User(code: 10).save().should.be.fulfilled
                new User(code: -10).save().should.be.rejected
                new User(code: '-10').save().should.be.rejected
            ]

            When.all(attempts).should.notify done

        it 'validates bounds', (done) ->
            User = define_model [F.IntField, 'code', greater_than: 1, less_than: 10]
            User::validations.code.should.deep.equal ['isInteger', 'greaterThan:1', 'lessThan:10']

            attempts = [
                new User(code: 5).save().should.be.fulfilled
                new User(code: 1).save().should.be.rejected
                new User(code: 10).save().should.be.rejected
            ]

            When.all(attempts).should.notify done

    describe 'FloatField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates floats', (done) ->
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

            When.all(attempts).should.notify done
    describe 'BooleanField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'stores boolean values', (done) ->
            User = define_model [F.BooleanField, 'flag']
            new User(flag: 'some string').save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.flag.should.be.true
                            done()
                        .otherwise (e) -> throw e
                .otherwise (e) -> done(e)

    describe 'DateTimeField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'stores Date objects', (done) ->
            User = define_model [F.DateTimeField, 'last_login']
            date = new Date('2013-09-25T15:00:00.000Z')
            new User(last_login: date).save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.last_login.should.be.an.instanceof Date
                            user.last_login.toISOString().should.equal date.toISOString()
                            done()
                        .otherwise (e) -> throw e
                .otherwise (e) -> done e

        it 'validates date', (done) ->
            User = define_model [F.DateTimeField, 'last_login']

            attempts = [
                new User(last_login: new Date()).save().should.be.fulfilled
                new User(last_login: new Date().toUTCString()).save().should.be.fulfilled
                new User(last_login: '1/1/1').save().should.be.fulfilled
                new User(last_login: 'foobar').save().should.be.rejected
            ]

            When.all(attempts).should.notify done

    describe 'DateField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        truncate_date = (d) -> new Date(d.getFullYear(), d.getMonth(), d.getDate())

        it 'stores Date objects', (done) ->
            User = define_model [F.DateField, 'birth_date']
            date = new Date('2013-09-25T15:00:00.000Z')
            new User(birth_date: date).save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.birth_date.should.be.an.instanceof Date
                            user.birth_date.toISOString().should.equal truncate_date(date).toISOString()
                            done()
                        .otherwise (e) -> throw e
                .otherwise (e) -> done e

        it 'validates date', (done) ->
            User = define_model [F.DateTimeField, 'birth_date']

            attempts = [
                new User(birth_date: new Date()).save().should.be.fulfilled
                new User(birth_date: new Date().toUTCString()).save().should.be.fulfilled
                new User(birth_date: '1/1/1').save().should.be.fulfilled
                new User(birth_date: 'foobar').save().should.be.rejected
            ]

            When.all(attempts).should.notify done

    describe 'JSONField', ->
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'stores JSON objects', (done) ->
            User = define_model [F.JSONField, 'additional_data']

            data  =
                nickname: 'bogus'
                interests: ['nodejs', 'photography', 'tourism']

            new User(additional_data: data).save()
                .then (user) ->
                    new User(id: user.id).fetch()
                        .then (user) ->
                            user.additional_data.should.deep.equal data
                            done()
                        .otherwise (e) -> throw e
                .otherwise (e) -> done e

        it 'validates JSON', (done) ->
            User = define_model [F.JSONField, 'additional_data']

            attempts = [
                new User(additional_data: {foo: 'bar'}).save().should.be.fulfilled
                new User(additional_data: JSON.stringify(foo: 'bar')).save().should.be.fulfilled
                new User(additional_data: 42).save().should.be.rejected
                new User(additional_data: 'not a json').save().should.be.rejected
            ]

            When.all(attempts).should.notify done

