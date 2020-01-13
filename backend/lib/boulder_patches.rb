# This include is for all of the defaults encoded in the MARCModel that we
# override locally for reasons about which we don't feel strongly enough to
# submit pull requests to core.
#
# Other customizations are in our decorator: Boulder_marc_serializer.rb

class MARCModel < ASpaceExport::ExportModel
  attr_reader :aspace_record
  attr_accessor :controlfields

  # include finding_aid_description_rules in @archival_object_map so we can
  # order the 040 subfields according to OCLC specifications
  @archival_object_map = {
    [:repository, :finding_aid_language, :finding_aid_description_rules] => :handle_repo_code,
    [:title, :linked_agents, :dates] => :handle_title,
    :linked_agents => :handle_agents,
    :subjects => :handle_subjects,
    :extents => :handle_extents,
    :lang_materials => :handle_languages
  }

  # we don't use the ead_loc method because we use the PUI for "finding aids"
  @resource_map = {
    [:id_0, :id_1, :id_2, :id_3] => :handle_id,
    [:id, :jsonmodel_type] => :handle_ark,
    :notes => :handle_notes
  }

  def initialize(obj, opts = {include_unpublished: false})
    @datafields = {}
    @controlfields = {}
    @include_unpublished = opts[:include_unpublished]
    @aspace_record = obj
  end

  def include_unpublished?
    @include_unpublished
  end

  def self.from_aspace_object(obj, opts = {})
    self.new(obj, opts)
  end

  def handle_repo_code(repository, *finding_aid_language, finding_aid_description_rules)
    repo = repository['_resolved']
    return false unless repo

    sfa = repo['org_code'] ? repo['org_code'] : "Repository: #{repo['repo_code']}"

    # ANW-529: options for 852 datafield:
    # 1.) $a => org_code || repo_name
    # 2.) $a => $parent_institution_name && $b => repo_name

    # if repo['parent_institution_name']
    #   subfields_852 = [
    #                     ['a', repo['parent_institution_name']],
    #                     ['b', repo['name']]
    #                   ]
    # elsif repo['org_code']
    #   subfields_852 = [
    #                     ['a', repo['org_code']],
    #                   ]
    # else
    #   subfields_852 = [
    #                     ['a', repo['name']]
    #                   ]
    # end

    # df('852', ' ', ' ').with_sfs(*subfields_852)

    df('040', ' ', ' ').with_sfs(['a', 'COD'], ['b', 'eng'], ['e', 'dacs'], ['c', 'COD'])

    df('049', ' ', ' ').with_sfs(['a', 'CODE'])

    if repo.has_key?('country') && !repo['country'].empty?

      # US is a special case, because ASpace has no knowledge of states, the
      # correct value is 'xxu'
      if repo['country'] == "US"
        df('044', ' ', ' ').with_sfs(['a', "xxu"])
      else
        df('044', ' ', ' ').with_sfs(['a', repo['country'].downcase])
      end
    end
  end

  def handle_languages(lang_materials)
    nil
  end
  # prefix 099$a with "MS" per local style guidelines
  def handle_id(*ids)
    ids.reject!{|i| i.nil? || i.empty? }
    df('099', ' ', '9').with_sfs(['a', ids.join('.')])
  end

  # if subject['source'] == 'built' export as 610
  # TODO: fix 610$2 == "local" if the real source is Library of Congress (inferred from authority_id)
  def handle_subjects(subjects)
    subjects.each do |link|
      subject = link['_resolved']
      term, *terms = subject['terms']
      code, ind2 =  case term['term_type']
                    when 'uniform_title'
                      ['630', source_to_code(subject['source'])]
                    when 'temporal'
                      ['648', source_to_code(subject['source'])]
                    # LOCAL: hack to export buildings as 610s, part 1
                    when 'topical'
                      if subject['source'] == 'built'
                        ['610', '7']
                      else
                        ['650', source_to_code(subject['source'])]
                      end
                    when 'geographic', 'cultural_context'
                      ['651', source_to_code(subject['source'])]
                    when 'genre_form', 'style_period'
                      ['655', source_to_code(subject['source'])]
                    when 'occupation'
                      ['656', '7']
                    when 'function'
                      ['656', '7']
                    else
                      ['650', source_to_code(subject['source'])]
                    end
      sfs = [['a', term['term']]]

      terms.each do |t|
        tag = case t['term_type']
              when 'uniform_title'; 't'
              when 'genre_form', 'style_period'; 'v'
              # LOCAL: occupation == 'x'
              when 'topical', 'cultural_context', 'occupation'; 'x'
              when 'temporal'; 'y'
              when 'geographic'; 'z'
              end
        sfs << [tag, t['term']]
      end

      # LOCAL: hack to export buildings as 610s, part 2
      if ind2 == '7'
        if subject['source'] == 'built'
          sfs << ['2', 'local']
        else
          sfs << ['2', subject['source']]
        end
      end

      ind1 = code == '630' ? "0" : " "
      df!(code, ind1, ind2).with_sfs(*sfs)
    end
  end

  def handle_notes(notes)

    notes.each do |note|

      prefix =  case note['type']
                when 'dimensions'; "Dimensions"
                when 'physdesc'; "Physical Description note"
                when 'materialspec'; "Material Specific Details"
                when 'physloc'; "Location of resource"
                when 'phystech'; "Physical Characteristics / Technical Requirements"
                when 'physfacet'; "Physical Facet"
                when 'processinfo'; "Processing Information"
                when 'separatedmaterial'; "Materials Separated from the Resource"
                else; nil
                end

      marc_args = case note['type']

                  # when 'arrangement', 'fileplan'
                  #   ['351', 'a']
                  # when 'odd', 'dimensions', 'physdesc', 'materialspec', 'physloc', 'phystech', 'physfacet', 'processinfo', 'separatedmaterial'
                  #   ['500','a']
                when 'odd', 'dimensions', 'materialspec', 'phystech', 'physfacet', 'processinfo', 'separatedmaterial'
                  ['500','a']
                  when 'accessrestrict'
                    ind1 = note['publish'] ? '1' : '0'
                    ['506', ind1, ' ', 'a']
                  # when 'scopecontent'
                  #   ['520', '3', ' ', 'a']
                  when 'abstract'
                    ['520', '3', ' ', 'a']
                  when 'prefercite'
                    ['524', ' ', ' ', 'a']
                  when 'acqinfo'
                    ind1 = note['publish'] ? '1' : '0'
                    ['541', ind1, ' ', 'a']
                  when 'relatedmaterial'
                    ind1 = note['publish'] ? '1' : '0'
                    ['544',ind1, ' ', 'a']
                  # when 'bioghist'
                  #     ['545',ind1,' ','a']
                  when 'custodhist'
                    ind1 = note['publish'] ? '1' : '0'
                    ['561', ind1, ' ', 'a']
                  when 'appraisal'
                    ind1 = note['publish'] ? '1' : '0'
                    ['583', ind1, ' ', 'a']
                  when 'accruals'
                    ['584', 'a']
                  when 'altformavail'
                    ['535', '2', ' ', 'a']
                  when 'originalsloc'
                    ['535', '1', ' ', 'a']
                  when 'userestrict', 'legalstatus'
                    ['540', 'a']
                  # when 'langmaterial'
                  #   ['546', 'a']
                  when 'otherfindaid'
                    ['555', '0', ' ', 'a']
                  else
                    nil
                  end

      unless marc_args.nil?
        text = prefix ? "#{prefix}: " : ""
        text += ASpaceExport::Utils.extract_note_text(note, @include_unpublished, true)

        # only create a tag if there is text to show (e.g., marked published or exporting unpublished)
        if text.length > 0
          df!(*marc_args[0...-1]).with_sfs([marc_args.last, *Array(text)])
        end
      end

    end
  end


  def self.from_resource(obj, opts = {})
    marc = self.from_archival_object(obj, opts)
    marc.apply_map(obj, @resource_map)
    marc.leader_string = "00000npcaa2200000la 4500"
    marc.leader_string[7] = obj.level == 'item' ? 'm' : 'c'

    marc.controlfield_string = assemble_controlfield_string(obj)

    marc
  end
  # export dimensions into 300|c subfield
  def handle_extents(extents)
    extents.each do |ext|
      e = ext['number'] + ' '
      t =  "#{I18n.t('enumerations.extent_extent_type.'+ext['extent_type'], :default => ext['extent_type'])}"

      if ext['container_summary']
        t << " (#{ext['container_summary']})"
      end

      if ext['dimensions']
        d = ext['dimensions']
      end



      df!('300').with_sfs(['a', e + t])
    end
  end
end
