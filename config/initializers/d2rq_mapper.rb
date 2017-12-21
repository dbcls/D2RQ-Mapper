require 'togo_mapper'

SECURE = ""
CIPHER = ""

EXAMPLE_RECORDS_MAX_ROWS = 5

DEFAULT_BASE_URI = 'http://localhost:2020/'

D2RQ_DUMPED_TURTLE_LINES = 100

rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
config = YAML.load_file(rails_root + '/config/d2rq-mapper.yml')
TogoMapper.d2rq_path = config['d2rq_path']

RESOURCE_CLASSES = {
  'dcterms' => %w( Agent AgentClass BibliographicResource FileFormat Frequency Jurisdiction LicenseDocument LinguisticSystem Location LocationPeriodOrJurisdiction MediaType MediaTypeOrExtent MethodOfAccrual MethodOfInstruction PeriodOfTime PhysicalMedium PhysicalResource Policy ProvenanceStatement RightsStatement SizeOrDuration Standard ),
  'foaf' => %w( Agent Document Group Image LabelProperty OnlineAccount OnlineChatAccount OnlineEcommerceAccount OnlineGamingAccuont Orgnization Person PersonalProfileDocument Project ),
  'rdf' => %w( Alt Bag List Property Seq Statement XMLLiteral ),
  'rdfs' => %w( Class Container ContainerMembershipProperty Datatype Literal Resource ),
  'skos' => %w( Collection Concept ConceptScheme OrderedCollection )
}

PROPERTIES = {
  'dc' => %w( contributor coverage creator date description format identifier language publisher relation rights source subject title type ),
  'dcterms' => %w( abstract accessRights accrualMethod accrualPeriodicity accrualPolicy alternative audience available bibliographicCitation conformsTo contributor coverage created creator date dateAccepted dateCopyrighted dateSubmitted description educationLevel extent format hasFormat hasPart hasVersion identifier instructionalMethod isFormatOf isPartOf isReferencedBy isReplacedBy isRequiredBy isVersionOf issued language license mediator medium modified provenance publisher references relation replaces requires rights rightsHolder source spatial subject tableOfContents temporal title type valid ),
  'rdf' => %w( first object predicate rest subject type value ),
  'rdfs' => %w( domain isDefinedBy range member seeAlso subClassOf subPropertyOf ),
  'skos' => %w( altLabel broadMatch changeNote definition editorialNote example hiddenLabel historyNote note prefLabel scopeNote )
}

DATATYPE_PROPERTIES = {
  'dcterms' => %w( Box ISO3166 ISO639-2 ISO639-3 Period Point RFC1766 RFC3066 RFC4646 RFC5646 URI W3CDTF ),
  'foaf' => %w( accountName age aimChatID birthday dnaChecksum familyName family_name firstName geekcode gender givenName givenname icqChatID jabberID lastName mbox_sha1sum msnChatID myersBriggs name nick plan sha1 skypeID status surname title yahooChatID ),
  'rdfs' => %w( label comment ),
  'skos' => %w( notation )
}

OBJECT_PROPERTIES = {
  'foaf' => %w( acount accountServiceHomepage based_near currentProject depiction depicts focus fundedBy holdsAccount homepage img interest knows logo made maker mbox member openid page pastProject phone primaryTopic publications schoolHomepage theme thumbnail tipjar topic topic_interest weblog workInfoHomepage workplaceHomepage ),
  'skos' => %w( broader broaderTransitive closeMatch exactMatch hasTopConcept inScheme mappingRelation member memberList narrowMatch narrower narrowerTransitive related relatedMatch semanticRelation topConceptOf )
}
