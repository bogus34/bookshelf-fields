chai = require("chai")
global.expect = chai.expect
global.should = chai.should()
global.assert = chai.assert
global.xsetTimeout = (t, f) -> setTimeout f, t
