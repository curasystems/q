# q

A simplified package manager for mcp. Delivers directories with some
meta information to a q-server and can download them again.

Upload and download is optimized to transfer binary diffs to a q-server.

**q** requires a package name, description, version and files to include/exclude. This is defined in the q.manifest.

## Commands

q --help 

## Api



## q.manifest

A manifest is required for telling q what the package is contained in the package

**Minimal Example**: q.manifest

    my-service:
        description: A little service that does not do much
        version: 0.2.0
        path: build/Release

The preceding manifest describes a package called 'my-service' with version 0.2.0. It includes all files in the folder build/Release relative to the manifest file itself.

> By default all files matched by .gitignore are not included. If .gitignore excludes node_modules it might be sensible to include the node\_modules folder explicitly using **include: ['node\_modules']**

### Defaults

Some fields in the manifest have defaults, so the example above could be rewritten as:

    my-service:
        description: A little service that does not do much

**version**: defaults to the version in a package.json when present next to the manifest or to the FileVersion of the only exe in the root path of the module. If the example above contained exactly one EXE in build/Release it would take its version. 

**path**: defaults to the manifest path

### Full example

    my-module:
        description: A little module others can use
        version: 2.0
        path: .
        include: ['node_modules']
        dependencies:
            mcp-server-web: ~0.0.1
        tags: ['web-module']
        web-module:
            alias: ['client','download']
            auth: ip
            application: webapp
            api: yes
        files:
            config: settings.yaml
            log: log.json

This manifest describes another module with some custom fields. The only fields relevant to q are *description*,*version*,*path*,*include*.

The other fields are custom fields users of the package can inspect. Usually the tags list is used to define types of packages and e.g. a package tagged with 'web-module' is usable  by other packages.



