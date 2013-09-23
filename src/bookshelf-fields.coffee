CheckIt = require 'checkit'

plugin = (instance) ->
    model = instance.Model.prototype
    model.validate = (self, attrs, options) ->
        if not ('validate' of options) or options.validate
            return CheckIt(@toJSON()).run(@validations)
    old_format = model.format
    model.format = (attrs, options) ->
        attrs = old_format.call this, attrs, options
        if @__meta? and @__meta.fields
            for f in @__meta.fields when 'format' of f
                f.format attrs, options
        attrs
    old_parse = model.parse
    model.parse = (resp, options) ->
        attrs = old_parse.call this, resp, options
        if @__meta? and @__meta.fields
            for f in @__meta.fields when 'parse' of f
                f.parse attrs, options
        attrs

class Field
    readable: true
    writable: true
    constructor: (@name, @options = {}) ->
        @validations = []
        @validations.push 'required' if @options.required
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

class StringField extends Field
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

class EmailField extends StringField
    constructor: (name, options) ->
        super name, options
        @validations.push 'validEmail'

class IntField extends Field
    constructor: (name, options) ->
        super name, options
        @_normalize_options()
        @validations.push 'isInteger'
        if @options.positive
            @validations.push 'isPositive'
        @validations.push "greaterThan:#{@options.greater_than}" if @options.greater_than?
        @validations.push "greaterThanEqualTo:#{@options.greater_than_equal_to}" if @options.greater_than_equal_to?
        @validations.push "lessThan:#{@options.less_than}" if @options.less_than?
        @validations.push "lessThanEqualTo:#{@options.less_than_equal_to}" if @options.less_than_equal_to?

    parse: (attrs) ->
        attrs[@name] = parseInt attrs[@name] if @name of attrs

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

enable_validation = (model) ->
    if model.prototype.initialize?
        old_init = model.prototype.initialize
        model.prototype.initialize = ->
            @on 'saving', @validate, this
            old_init.apply this, arguments
    else
        model.prototype.initialize = ->
            @on 'saving', @validate, this

field = (model, cls, name, options) ->
    f = new cls name, options
    f.contribute_to_model model

fields = (model, specs...) ->
    for [cls, name, options] in specs
        field model, cls, name, options

pollute_function_prototype = ->
    Function::field = (cls, name, options) -> field this, cls, name, options
    Function::fields = (specs...) -> specs.unshift this; fields.apply this, specs
    Function::enable_validation = -> enable_validation this

cleanup_function_prototype = ->
    delete Function::field
    delete Function::fields
    delete Function::enable_validation

module.exports =
    plugin: plugin
    field: field
    fields: fields
    enable_validation: enable_validation
    pollute_function_prototype: pollute_function_prototype
    cleanup_function_prototype: cleanup_function_prototype

    Field: Field
    StringField: StringField
    EmailField: EmailField
    IntField: IntField
