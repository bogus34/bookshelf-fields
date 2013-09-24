Bookshelf = require 'bookshelf'
F = require '../src/bookshelf-fields'
When = require 'when'

describe "Bookshelf fields", ->
    this.timeout 3000
    db = null
    User = Users = null

    before (done) ->
        db = Bookshelf.initialize
            client: 'sqlite'
            debug: true
            connection:
                filename: './test/test.db'
        db.plugin F.plugin
        knex = db.knex
        knex.schema.dropTableIfExists('users')
            .then ->
                knex.schema.createTable 'users', (table) ->
                    table.increments('id').primary()
                    table.string 'username', 255
                    table.string 'email', 255
                    table.float 'code'
                .then ->
                    done()
                .otherwise (errors) ->
                    console.log errors
                    throw errors

    describe 'common behaviour', ->
        beforeEach ->
            F.pollute_function_prototype()

            class User extends db.Model
                tableName: 'users'
                @field F.StringField, 'username', min_length: 3, max_length: 15
                @field F.EmailField, 'email'
                @enable_validation()

            class Users extends db.Collection
                model: User

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

    describe 'StringField', ->
        User = null
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates min_length and max_length', (done) ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @fields \
                    [F.StringField, 'username', min_length: 5, max_length: 10]

            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

            attempts = [
                new User(username: 'foo').save().should.be.rejected
                new User(username: 'Some nickname that is longer then 10 characters').save().should.be.rejected
                new User(username: 'justfine').save().should.be.fulfilled
            ]

            When.all(attempts).should.notify done

        it 'uses additional names for length restrictions', ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @field F.StringField, 'username', minLength: 5, maxLength: 10

            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

    describe 'EmailField', ->
        User = null
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates email', (done) ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @field F.EmailField, 'email'

            User::validations.email.should.deep.equal ['validEmail']

            attempts = [
                new User(email: 'foo').save().should.be.rejected
                new User(email: 'foo@bar.com').save().should.be.fulfilled
            ]

            When.all(attempts).should.notify done

    describe 'IntField', ->
        User = null
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates integers', (done) ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @field F.IntField, 'code'

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
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @field F.IntField, 'code', positive: true

            User::validations.code.should.deep.equal ['isInteger', 'isPositive']

            attempts = [
                new User(code: 10).save().should.be.fulfilled
                new User(code: -10).save().should.be.rejected
                new User(code: '-10').save().should.be.rejected
            ]

            When.all(attempts).should.notify done

        it 'validates bounds', (done) ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @field F.IntField, 'code', greater_than: 1, less_than: 10

            User::validations.code.should.deep.equal ['isInteger', 'greaterThan:1', 'lessThan:10']

            attempts = [
                new User(code: 5).save().should.be.fulfilled
                new User(code: 1).save().should.be.rejected
                new User(code: 10).save().should.be.rejected
            ]

            When.all(attempts).should.notify done

    describe 'FloatField', ->
        User = null
        before ->
            F.pollute_function_prototype()
        after (done) ->
            F.cleanup_function_prototype()
            db.knex('users').del().then -> done()

        it 'validates floats', (done) ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @field F.FloatField, 'code'

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
