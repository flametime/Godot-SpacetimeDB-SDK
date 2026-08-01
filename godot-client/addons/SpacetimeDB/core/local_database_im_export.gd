extends Resource
class_name DBImExporter

@export var db_data: Dictionary[String,Array]

static func load_db_data(local_db: LocalDatabase, load_folder: String, table_name: StringName)-> Error:
	if not FileAccess.file_exists(load_folder+"/"+table_name+".tres"):
		return Error.ERR_FILE_NOT_FOUND
	var res : DBImExporter= ResourceLoader.load(load_folder+"/"+table_name+".tres", "DBImExporter")
	var table_inserts: TableUpdateData = TableUpdateData.new()
	table_inserts.table_name = table_name
	table_inserts.inserts.assign(res.db_data[table_name])
	table_inserts.num_rows = table_inserts.inserts.size()
	local_db.apply_table_update(table_inserts)
	return OK

static func save_db_data(local_db: LocalDatabase, save_folder: String, table_name: StringName)-> Error:
	if not DirAccess.dir_exists_absolute(save_folder):
		var err = DirAccess.make_dir_recursive_absolute(save_folder)
		if err != OK:
			return err
	var res := DBImExporter.new()
	var rows := local_db.get_all_rows(table_name)
	res.db_data.set(table_name, rows)
	return ResourceSaver.save(res,save_folder+"/"+table_name+".tres")
