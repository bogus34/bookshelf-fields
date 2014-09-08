CheckIt = require 'checkit'

deep_clone = (obj) ->
    res = {}
    for k, v of obj
        switch
            when v instanceof Array
                res[k] = v[..]
            when typeof v is 'object'
                res[k] = deep_clone v
            else
                res[k] = v
    res

plugin = (options) -> (instance) ->
    instance.__helpers_fp ?= {}
    instance.__helpers_fp.enable_validation = (options) -> enable_validation(this, options)
    instance.__helpers_fp.field = (args...) -> field this, args...
    instance.__helpers_fp.fields = (args...) -> fields this, args...

    options ?= {}
    options.create_properties ?= true
    instance.Model.prototype.__bookshelf_fields_options = options
    instance.Checkit = CheckIt

    model = instance.Model.prototype
    model.validate = (self, attrs, options = {}) ->
        if not ('validate' of options) or options.validate
            json = @toJSON(validating: true)
            checkit = CheckIt(@validations, @validation_options).run(json)
            if @model_validations? and @model_validations instanceof Array and @model_validations.length > 0
                model_validations = @model_validations
                checkit = checkit.then ->
                    CheckIt(all: model_validations).run(all: json)
            checkit
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

enable_validation = (model, options) ->
    if model.prototype.initialize?
        old_init = model.prototype.initialize
        model.prototype.initialize = ->
            @on 'saving', @validate, this
            old_init.apply this, arguments
    else
        model.prototype.initialize = ->
            @on 'saving', @validate, this
    model.prototype.validation_options = options if options

field = (model, cls, name, options) ->
    f = new cls name, options
    f.contribute_to_model model

fields = (model, specs...) ->
    for [cls, name, options] in specs
        field model, cls, name, options

exports =
    plugin: plugin
    field: field
    fields: fields
    enable_validation: enable_validation

for k, f of require('./fields')
    exports[k] = f

module.exports = exports
