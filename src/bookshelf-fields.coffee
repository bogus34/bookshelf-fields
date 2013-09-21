CheckIt = require 'checkit'

plugin = (instance) ->
    model = instance.Model.prototype
    model.validate = (self, attrs, options) ->
        if not ('validate' of options) or options.validate
            return CheckIt(@toJSON()).run(@validations)

enable_validation = (self) ->
    if self.prototype.initialize?
        old_init = self.prototype.initialize
        self.prototype.initialize = ->
            @on 'saving', @validate, this
            old_init.apply this, arguments
    else
        self.prototype.initialize = ->
            @on 'saving', @validate, this

class Field
    readable: true
    writable: true
    constructor: (@name, @options = {}) ->
        @validations = []
        @validations.push 'required' if @options.required
    contribute_to_model: (model) ->
        proto = model.prototype
        proto._meta ?= {}
        proto._meta.fields ?= []
        proto._meta.fields.push this
        @append_validations(model)
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
        @validations.push "minLength:#{@options.min_length}" if @options.min_length?
        @validations.push "maxLength:#{@options.max_length}" if @options.max_length?

Function::field = (cls, name, options) ->
    f = new cls name, options
    f.contribute_to_model this

module.exports =
    plugin: plugin
    enable_validation: enable_validation
    Field: Field
    StringField: StringField

