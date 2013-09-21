{spawn} = require "child_process"

# REPORTER = "dot"         # dot matrix
# REPORTER = "doc"         # html documentation
REPORTER = "spec"        # hierarchical spec list
# REPORTER = "json"        # single json object
# REPORTER = "progress"    # progress bar
# REPORTER = "list"        # spec-style listing
# REPORTER = "tap"         # test-anything-protocol
# REPORTER = "landing"     # unicode landing strip
# REPORTER = "xunit"       # xunit reportert
# REPORTER = "teamcity"    # teamcity ci support
# REPORTER = "html-cov"    # HTML test coverage
# REPORTER = "json-cov"    # JSON test coverage
# REPORTER = "min"         # minimal reporter (great with -watch)
# REPORTER = "json-stream" # newline delimited json events
# REPORTER = "markdown"    # markdown documentation (github flavour)
# REPORTER = "nyan"        # nyan cat!

mocha = './node_modules/.bin/mocha'
coffee = './node_modules/.bin/coffee'

task "test", "run tests", (options) ->
    env = process.env
    env['NODE_ENV'] = 'test'
    spawn mocha,
        ['--compilers', 'coffee:coffee-script',
        '--reporter', "#{REPORTER}",
        '--require', 'coffee-script',
        '--require', 'test/test_helper.coffee',
        '--colors', 'test/'],
        'env': env, 'cwd': process.cwd(), 'stdio': 'inherit'

task "build", "build library", ->
    env = process.env
    spawn coffee,
        ['--compile', '-o', 'lib/', 'src/bookshelf-fields.coffee'],
        'env': env, 'cwd': process.cwd(), 'stdio': 'inherit'

