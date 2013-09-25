e = {}
e.Field = class Field
    readable: true
    writable: true
    constructor: (@name, @options = {}) ->
        @validations = []
        @model_validations = []
        @validations.push 'required' if @options.required
        if 'nullable' of @options and !@options.nullable
            name = @name
            @model_validations.push (value) -> value[name]?
        if 'choices' of @options
            @validations.push @_validate_choices
    contribute_to_model: (model) ->
        proto = model.prototype
        proto.__meta ?= {}
        proto.__meta.fields ?= []
        proto.__meta.fields.push this
        @append_validations(model)
        @create_property(model) unless @name is 'id'
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
    _validate_choices: (value) =>
        choices = @options.choices
        comparator = if @options.comparator? then @options.comparator else (a, b) -> a == b
        if choices instanceof Array
            for variant in choices
                return true if comparator(value, variant)
        else if typeof choices is 'object'
            for variant of choices
                return true if comparator(value, variant)
        false

e.StringField = class StringField extends Field
    constructor: (name, options) ->
        super name, options
        @_normalize_options()
        @validations.push "minLength:#{@options.min_length}" if @options.min_length?
        @validations.push "maxLength:#{@options.max_length}" if @options.max_length?

    _normalize_options: ->
        for k of @options
            switch k
                when 'minLength'
                    @options.min_length = @options[k]
                    delete @options[k]
                when 'maxLength'
                    @options.max_length = @options[k]
                    delete @options[k]

e.EmailField = class EmailField extends StringField
    constructor: (name, options) ->
        super name, options
        @validations.push 'validEmail'

e.NumberField = class NumberField extends Field
    constructor: (name, options) ->
        super name, options
        @_normalize_options()
        if @options.positive
            @validations.push 'isPositive'
        @validations.push "greaterThan:#{@options.greater_than}" if @options.greater_than?
        @validations.push "greaterThanEqualTo:#{@options.greater_than_equal_to}" if @options.greater_than_equal_to?
        @validations.push "lessThan:#{@options.less_than}" if @options.less_than?
        @validations.push "lessThanEqualTo:#{@options.less_than_equal_to}" if @options.less_than_equal_to?

    _normalize_options: ->
        for k of @options
            switch k
                when 'gt', 'greaterThan'
                    @options.greater_than = @options[k]
                    delete @options[k]
                when 'gte', 'greaterThanEqualTo', 'min'
                    @options.greater_than_equal_to = @options[k]
                    delete @options[k]
                when 'lt', 'lessThan'
                    @options.less_than = @options[k]
                    delete @options[k]
                when 'lte', 'lessThanEqualTo', 'max'
                    @options.less_than_equal_to = @options[k]
                    delete @options[k]


e.IntField = class IntField extends NumberField
    constructor: (name, options) ->
        super name, options
        @validations.unshift 'isInteger'

    parse: (attrs) ->
        attrs[@name] = parseInt attrs[@name] if @name of attrs

e.FloatField = class FloatField extends NumberField
    constructor: (name, options) ->
        super name, options
        @validations.unshift 'isNumeric'

    parse: (attrs) ->
        attrs[@name] = parseFloat attrs[@name] if @name of attrs

e.BooleanField = class BooleanField extends Field
    parse: (attrs) ->
        attrs[@name] = !!attrs[@name] if @name of attrs
    format: (attrs) ->
        attrs[@name] = !!attrs[@name] if @name of attrs

module.exports = e
