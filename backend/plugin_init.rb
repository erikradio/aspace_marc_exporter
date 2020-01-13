require_relative 'lib/boulder_marc_serializer'
require_relative 'lib/boulder_marc_exporter'
require_relative 'lib/boulder_patches'

MARCSerializer.add_decorator(BoulderMARCSerializer)
