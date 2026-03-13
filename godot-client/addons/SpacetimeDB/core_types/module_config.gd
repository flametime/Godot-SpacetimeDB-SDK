extends Resource
class_name SpacetimeDBModuleConfig

@export var name: String
@export var alias: String
@export_category("Codegen Config")
@export var hide_private_tables: bool = true

@export var unparsed_module_schema : String
@export var parsed_schema : SpacetimeParsedSchema
