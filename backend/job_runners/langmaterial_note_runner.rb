require 'java'
require 'json'

class LangMaterialNoteRunner < JobRunner

  register_for_job_type('langmaterial_note_job',
                        :create_permissions => :manage_repository,
                        :cancel_permissions => :manage_repository,
                        :run_concurrently => true)

  def run

    begin

      modified_records = []

      job_data = @json.job

      # we need to massage the json sometimes..
      begin
        params = ASUtils.json_parse(@json.job_params[1..-2].delete("\\"))
      rescue JSON::ParserError
        params = {}
      end
      params[:note_string] = job_data['note_string']
      params[:language] = job_data['language']
      params[:delete_note] = job_data['delete_note']
      params[:all_repos] = job_data['all_repos']

      log(Time.now)

      DB.open do |db|

        def query_string(params)
          "SELECT
              id, repo_id
          FROM
              as_126.resource
          WHERE
              id NOT IN (SELECT
                      resource_id
                  FROM
                      as_126.lang_material
                  WHERE
                      id IN (SELECT
                              lang_material_id
                          FROM
                              as_126.language_and_script)
                          AND resource_id IS NOT NULL)
                  #{params[:all_repos] == true ? "" : "AND repo_id = #{@job.repo_id}"};"
        end

        unless params[:language].nil? && params[:note_string]
          lang_enum = db[:enumeration].filter(:name => 'language_iso639_2').select(:id)
          new_lang = db[:enumeration_value].filter(:value => params[:language], :enumeration_id => lang_enum ).select(:id)
          no_lang = db.fetch(query_string(params))
          no_lang.each do |resource|
            lang_material_note = db[:lang_material].filter(:resource_id => resource[:id]).select(:id)
            lang_material_note.each do |note|
              note_blob = db[:note].filter(:lang_material_id => lang_material_note).get([:id, :notes])
              if JSON.parse(note_blob[1])['content'][0] == params[:note_string]
                # Create lang_material record attached to resource
                language_record = db[:lang_material].insert(
                                      :json_schema_version => 1,
                                      :resource_id => resource[:id],
                                      :create_time => Time.now,
                                      :system_mtime => Time.now,
                                      :user_mtime => Time.now
                                    )

                # Create language_and_script record with the user-provided language
                db[:language_and_script].insert(
                                      :json_schema_version => 1,
                                      :language_id => new_lang,
                                      :lang_material_id => language_record,
                                      :create_time => Time.now,
                                      :system_mtime => Time.now,
                                      :user_mtime => Time.now
                                    )

                uri = "/repositories/#{resource[:repo_id]}/resources/#{resource[:id]}"
                modified_records << uri
                if params[:delete_note] == true
                  @job.write_output("Deleting Language of Material note with content '#{params[:note_string]}' and associated subrecords.")
                  # Safely delete the note
                  Note.handle_delete(note_blob[0])
                  # Delete now empty langmaterial record
                  db[:lang_material].filter(note).delete
                end
              # Ensure that the parent resource will be re-indexed
              db[:resource].where(:id => resource[:id]).update(
                                                                :system_mtime => Time.now,
                                                                :user_mtime => Time.now
                                                              )
              end
            end
          end

        end

      end

      if modified_records.empty?
        @job.write_output("All done, no records modified.")
      else
        @job.write_output("#{modified_records.uniq.count} records modified.")
        @job.write_output("All done, logging modified records.")
      end

      self.success!

      log("===")

      @job.record_created_uris(modified_records.uniq)

      rescue Exception => e
        @job.write_output(e.message)
        @job.write_output(e.backtrace)
        raise e

      ensure
        @job.write_output("Done.")

    end

  end

  def log(s)
    Log.debug(s)
    @job.write_output(s)
  end

end
