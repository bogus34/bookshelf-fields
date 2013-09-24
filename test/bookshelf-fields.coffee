Bookshelf = require 'bookshelf'
F = require '../src/bookshelf-fields'

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
        after ->
            F.cleanup_function_prototype()

        it 'validates min_length and max_length', (done) ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @fields \
                    [F.StringField, 'username', min_length: 5, max_length: 10]

            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']

            new User(username: 'foo').save()
                .otherwise (errors) ->
                    new User(username: 'Some nickname that is longer then 10 characters').save()
                        .otherwise (errors) ->
                            done()
                            new User(username: 'justfine').save()
                                .then (user) ->
                                    user.destroy().then -> done()
                                .otherwise (errors) ->
                                    console.log errors
                                    done new Error('validation breaked with normal-length string')
                            throw errors # break promise resolution
                        .then ->
                            done new Error('validation passed with short string')
                    throw errors  # break promise resolution
                .then ->
                    done new Error('validation passed with short string')

        it 'uses additional names for length restrictions', ->
            class User extends db.Model
                tableName: 'users'
                @enable_validation()
                @fields \
                    [F.StringField, 'username', minLength: 5, maxLength: 10]

            User::validations.username.should.deep.equal ['minLength:5', 'maxLength:10']
