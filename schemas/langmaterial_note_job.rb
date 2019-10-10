{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {

      "note_string" => {
        "type" => "string",
        "maxLength" => 255
      },
      "language" => {
        "type" => "string",
        "dynamic_enum" => "language_iso639_2"
      },
      "delete_note" => {
        "type" => "boolean",
        "default" => false
      },
      "all_repos" => {
        "type" => "boolean",
        "default" => false
      }

    }
  }
}
