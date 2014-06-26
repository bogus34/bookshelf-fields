isArray = require('util').isArray
e = {}
e.Field = class Field
    readable: true
    writable: true
    constructor: (@name, @options = {}) ->
        @options.create_property ?= true
        @validations = []
        @model_validations = []
        @_accept_rule 'required'
        @_accept_rule 'exists'
        if 'choices' of @options
            @validations.push @normalize_rule @_validate_choices, @options.choices

        if 'validations' of @options
            @validations.push.apply @validations, @options.validations

    plugin_option: (name) -> @model::__bookshelf_fields_options[name]

    contribute_to_model: (model) ->
        @model = model
        proto = model.prototype
        proto.__meta ?= {}
        proto.__meta.fields ?= []
        proto.__meta.fields.push this
        @append_validations(model)

        if @plugin_option('create_properties') and
          @options['create_property'] and
          @name isnt 'id' and
          @name not of model.prototype

            @create_property(model)

    append_validations: (model) ->
        proto = model.prototype
        proto.validations ?= {}
        if @name of proto.validations
            if not (proto.validations[@name] instanceof Array)
                proto.validations[@name] = [proto.validations[@name]]
        else
            proto.validations[@name] = []
        proto.validations[@name].push.apply proto.validations[@name], @validations
        if @model_validations.length > 0
            proto.model_validations ?= []
            proto.model_validations.push.apply proto.model_validations, @model_validations
    create_property: (model) ->
        proto = model.prototype
        spec = {}
        spec.get = @mk_getter() if @readable
        spec.set = @mk_setter() if @writable
        Object.defineProperty proto, @name, spec
    mk_getter: ->
        name = @name
        -> @get name
    mk_setter: ->
        name = @name
        (value) -> @set name, value
    normalize_rule: (rule, value) ->
        @_with_message switch
            when typeof value is 'object' and not isArray(value)
                result = rule: rule
                for k, v of value
                    result[k] = v
                if 'value' of result
                    if typeof rule is 'string'
                        result.rule += ':' + result.value
                    else
                        result.params = result.value
                    delete result.value
                result.params ||= []
                result
            when typeof value is 'boolean'
                rule
            when typeof rule is 'string'
                "#{rule}:#{value}"
            else
                @normalize_rule rule, value: value

    _validate_choices: (value, choices...) =>
        comparator = if @options.comparator? then @options.comparator else (a, b) -> a == b
        for variant in choices
            return true if comparator(value, variant)
        false

    _accept_rule: (names, rule) ->
        names = [names] unless isArray names
        rule ?= names[0]
        for name in names when name of @options
            @validations.push @normalize_rule rule, @options[name]
            return

    _with_message: (rule) ->
        return rule unless @options.message? or @options.label?
        rule = {rule: rule} if typeof rule isnt 'object'
        rule.message ?= @options.message if @options.message?
        rule.label ?= @options.label if @options.label?
        rule

e.StringField = class StringField extends Field
    constructor: (name, options) ->
        super name, options
        @_accept_rule ['minLength', 'min_length']
        @_accept_rule ['maxLength', 'max_length']


e.EmailField = class EmailField extends StringField
    constructor: (name, options) ->
        super name, options
        @validations.push @_with_message 'email'

e.NumberField = class NumberField extends Field
    constructor: (name, options) ->
        super name, options
        @_accept_rule ['naturalNonZero', 'positive']
        @_accept_rule 'natural'
        @_accept_rule ['greaterThan', 'greater_than', 'gt']
        @_accept_rule ['greaterThanEqualTo', 'greater_than_equal_to', 'gte', 'min']
        @_accept_rule ['lessThan', 'less_than', 'lt']
        @_accept_rule ['lessThanEqualTo', 'less_than_equal_to', 'lte', 'max']

e.IntField = class IntField extends NumberField
    constructor: (name, options) ->
        super name, options
        @validations.unshift @_with_message 'integer'

    parse: (attrs) ->
        attrs[@name] = parseInt attrs[@name] if @name of attrs

e.FloatField = class FloatField extends NumberField
    constructor: (name, options) ->
        super name, options
        @validations.unshift @_with_message 'isNumeric'

    parse: (attrs) ->
        attrs[@name] = parseFloat attrs[@name] if @name of attrs

e.BooleanField = class BooleanField extends Field
    parse: (attrs) ->
        attrs[@name] = !!attrs[@name] if @name of attrs
    format: (attrs) ->
        attrs[@name] = !!attrs[@name] if @name of attrs

e.DateTimeField = class DateTimeField extends Field
    constructor: (name, options) ->
        super name, options

        @validations.push @_with_message @_validate_datetime

    parse: (attrs) ->
        attrs[@name] = new Date(attrs[@name]) if @name of attrs
    format: (attrs) ->
        attrs[@name] = new Date(attrs[@name]) if @name of attrs and attrs[@name] not instanceof Date

    _validate_datetime: (value) ->
        return true if value instanceof Date
        return true if typeof value is 'string' and not isNaN(Date.parse(value))
        false

e.DateField = class DateField extends DateTimeField
    parse: (attrs) ->
        if @name of attrs
            d = new Date(attrs[@name])
            attrs[@name] = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    format: (attrs) ->
        if @name of attrs
            d = unless attrs[@name] instanceof Date then new Date(attrs[@name]) else attrs[@name]
            attrs[@name] = new Date(d.getFullYear(), d.getMonth(), d.getDate())

e.JSONField = class JSONField extends Field
    constructor: (name, options) ->
        super name, options
        @validations.push @_with_message @_validate_json
    format: (attrs) ->
        return unless attrs[@name] and typeof attrs[@name] is 'object'
        attrs[@name] = JSON.stringify attrs[@name]
    parse: (attrs) ->
        return unless attrs[@name] and typeof attrs[@name] is 'string'
        attrs[@name] = JSON.parse attrs[@name]
    _validate_json: (value) ->
        return true if typeof value is 'object'
        return false unless typeof value is 'string'
        JSON.parse value
        true

module.exports = e
