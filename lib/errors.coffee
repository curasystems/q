# Errors
module.exports.InvalidManifestError = class InvalidManifestError extends Error
    constructor:(@details)->

module.exports.ArgumentError = class ArgumentError extends Error
    constructor:(@message)->super(@message)

module.exports.NoListingError = class NoListingError extends Error
    constructor:(@message)->super(@message)
