# Our decorator class is for additions we make to the MARC export that aren't
# explicitly defined in the default ArchivesSpace MARCModel.
#
# Customizations we make that require overriding default ArchivesSpace behavior
# may be found in our patch include: Boulder_patches.rb
#
# Eventually I would like to do like NYU does and have this throw errors if
# your datafields and subfields aren't structured correctly, but as long as I'm
# the only one maintaining this thing I'll let it slide for now...

class BoulderMARCSerializer

  ControlField = Struct.new(:tag, :text)
  SubField = Struct.new(:code, :text)

  class DataField
    attr_accessor :tag
    attr_accessor :ind1
    attr_accessor :ind2
    attr_accessor :subfields

    def initialize(*args)
      @tag, @ind1, @ind2 = *args
      @subfields = []
    end

    def with_sfs(*sfs)
      sfs.each do |sf|
        subfield = SubField.new(sf[0],sf[1])
        @subfields << subfield
      end

      return self
    end
  end


  def initialize(record)
    @record = record
  end

  def leader_string
    result = @record.leader_string
  end

  def controlfield_string
    result = @record.controlfield_string
  end

  def controlfields
    cf = []

    if @record.aspace_record.has_key?('user_defined') && @record.aspace_record['user_defined'].has_key?('string_2')
      cf << ControlField.new('001', @record.aspace_record['user_defined']['string_2'])
    end

    @record.controlfields = cf
  end

  def datafields
    fields = []

    # hard-coded RDA 33X defaults
    # (to one day customize based on indicated form/genre, but we're copping out for now)
    # fields << DataField.new('336', ' ', ' ').with_sfs(['a', 'unspecified'], ['b', 'zzz'], ['2', 'rdacontent'])
    # fields << DataField.new('337', ' ', ' ').with_sfs(['a', 'unmediated'], ['b', 'n'], ['2', 'rdamedia'])
    # fields << DataField.new('338', ' ', ' ').with_sfs(['a', 'unspecified'], ['b', 'zu'], ['2', 'rdacarrier'])

    # this is so gross but this is how we add 856 datafields for the repository
    # if @record.aspace_record.has_key?('external_documents')
    #   @record.aspace_record['external_documents'].each do |doc|
    #     if doc['title'] == "Special Collections @ DU"
    #       fields << DataField.new('856', '4', '2').with_sfs(['z', "Access collection materials in Special Collections @ DU"], ['u', doc['location']])
    #     end
    #   end
    # end


    # link to the PUI for each resource in lieu of ASpace's default FA locations
    fields << DataField.new('856', '4', '2').with_sfs(['z', "Finding Aid (via ArchivesSpace)"], ['u', "https://archives.colorado.edu#{@record.aspace_record.uri}"])

    # add OCLC numbers in MARC 035
    # if @record.aspace_record.has_key?('user_defined')
    #   if @record.aspace_record['user_defined'].has_key?('string_3')
    #     text = "(OCoLC)"
    #     text += @record.aspace_record['user_defined']['string_3'].delete("http://worldcat.org/oclc/")
    #     fields << DataField.new('035', ' ', ' ').with_sfs(['a', text])
    #   end
    # end

    result = (@record.datafields + fields)
  end

end
