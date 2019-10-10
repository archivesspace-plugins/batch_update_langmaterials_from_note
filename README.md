# batch_update_langmaterials_from_note

A plugin to batch update language of materials records for resource records currently lacking a controlled value language.

## To install:

1. Stop the application
2. Clone the plugin into the `archivesspace/plugins` directory
3. Add `batch_update_langmaterials_from_note` to `config.rb`, ensuring to uncomment/remove the # from the front of the relevant AppConfig line.  For example:
`AppConfig[:plugins] = ['local', 'batch_update_langmaterials_from_note']`
4. Restart the application
