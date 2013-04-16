chai = require("chai")
chai.should()

sinon = require("sinon")
sinonChai = require("sinon-chai")
chai.use(sinonChai)

module.exports = { expect:chai.expect, sinon:sinon }
