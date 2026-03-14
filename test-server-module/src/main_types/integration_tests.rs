use std::fmt::Display;
use spacetimedb::*;

#[derive(Debug, SpacetimeType, Clone, Default)]
pub enum TestEnum {
    #[default]
    A,
    B,
}

impl Display for TestEnum {
    fn fmt(&self, formatter: &mut std::fmt::Formatter) -> std::fmt::Result {
        formatter.write_fmt(format_args!("{:?}", self))
    }
}

#[derive(Debug, SpacetimeType, Clone)]
pub enum TestNestedEnum{
    OK(u64),
    OkEmpty,
    Err(Box<[u8]>),
    InternalError(Box<str>),
    Test(TestScheduledTable),

}

#[derive(Debug, SpacetimeType, Clone)]
pub struct  TestType {
    pub test_name : String,
    pub test_int: u64,
    pub test_nested_enum: TestNestedEnum
}

#[table(accessor = test_table_datatypes, public)]
pub struct TestTableDatatypes {
    #[primary_key]
    #[auto_inc]
    pub t_u64: u64,
    pub t_u8: u8,
    pub t_u16: u16,
    #[index(btree)]
    pub t_u32: u32,
    pub t_u128: u128,
    // pub f16: f16, // stdb doesn't support it
    pub t_f32: f32,
    pub t_f64: f64,
    //pub f128: f128, // stdb doesn't support it
    pub t_i8: i8,
    pub t_i16: i16,
    pub t_i32: i32,
    pub t_i64: i64,
    // pub t_i128: i128, // client BSATNDeserializer doesn't support it
    pub t_string: String,
    pub t_vec_string: Vec<String>,
    pub t_vec_u8: Vec<u8>,
    pub t_opt_string: Option<String>,
    pub t_opt_u64: Option<u64>,
    pub t_test_enum: TestEnum,
    pub t_test_enum_vec: Vec<TestEnum>,
    pub t_test_enum_option: Option<TestEnum>,
    pub t_test_type: TestType,
    pub t_test_type_vec: Vec<TestType>,
    pub t_test_type_option: Option<TestType>,
}

impl Default for TestTableDatatypes {
    fn default() -> Self {
        TestTableDatatypes {
            t_u64: 0,
            t_u8: 0,
            t_u16: 0,
            t_u32: 0,
            t_u128: 0,
            t_f32: 0.0,
            t_f64: 0.0,
            t_i8: 0,
            t_i16: 0,
            t_i32: 0,
            t_i64: 0,
            t_string: "".to_string(),
            t_vec_string: vec!["".to_string()],
            t_vec_u8: vec![0],
            t_opt_string: Some("".to_string()),
            t_opt_u64: Some(0),
            t_test_enum: TestEnum::default(),
            t_test_enum_vec: vec![TestEnum::default()],
            t_test_enum_option: Some(TestEnum::default()),
            t_test_type: TestType{ test_name: "test_name".to_string(), test_int: 1, test_nested_enum: TestNestedEnum::OkEmpty },
            t_test_type_vec: vec![TestType{ test_name: "test_name".to_string(), test_int: 1 , test_nested_enum: TestNestedEnum::OkEmpty}],
            t_test_type_option: Some(TestType{ test_name: "test_name".to_string(), test_int: 1, test_nested_enum: TestNestedEnum::OkEmpty }),
        }
    }
}
#[derive(Debug, Clone)]
#[table(accessor = test_scheduled_table, public, scheduled(test_scheduled_reducer), index(accessor = get_by_public_count, btree(columns = [public_count])))]
pub struct TestScheduledTable {
    #[primary_key]
    #[auto_inc]
    pub scheduled_id: u64,
    pub h1: u16,
    pub scheduled_at: ScheduleAt,
    pub h2: u16,
    pub public_count: u64,
    pub private_count: u64,
}

#[reducer]
pub fn test_scheduled_reducer(ctx: &ReducerContext, mut row: TestScheduledTable) {
    row.private_count += 1;
    row.public_count += 1;
    // ctx.db.test_no_pk_table().insert(ViewType{ row: row.public_count, name: "Hello World".to_string() });
    ctx.db.test_scheduled_table().scheduled_id().update(row);
    if ctx.db.test_table_datatypes().count() < 10 {
        ctx.db.test_table_datatypes().insert(TestTableDatatypes::default());
    }
    for row in ctx.db.test_table_datatypes().iter() {
        ctx.db
            .test_table_datatypes()
            .t_u64()
            .update(TestTableDatatypes {
                t_u64: row.t_u64,
                t_u8: row.t_u8 + 1,
                t_u16: row.t_u16 + 1,
                t_u32: row.t_u32 + 1,
                t_u128: row.t_u128 + 1,
                t_f32: row.t_f32 - 0.0001,
                t_f64: row.t_f64 - 0.0001,
                t_i8: row.t_i8 - 1,
                t_i16: row.t_i16 - 1,
                t_i32: row.t_i32 - 1,
                t_i64: row.t_i64 - 1,
                //t_i128: row.t_i128 - 1,
                t_string: row.t_u8.to_string(),
                t_vec_string: vec![row.t_u8.to_string(), row.t_i16.to_string()],
                t_vec_u8: vec![row.t_u8, row.t_u8],
                t_opt_string: if row.t_opt_string.is_some() {
                    None
                } else {
                    Some("Some".to_string())
                },
                t_opt_u64: if row.t_opt_u64.is_some() {
                    None
                } else {
                    Some(row.t_u64)
                },
                t_test_enum: TestEnum::A,
                t_test_enum_option: Some(TestEnum::A),
                t_test_enum_vec: vec![TestEnum::A, TestEnum::B],
                t_test_type: TestType{ test_name: "test_name".to_string(), test_int: 1, test_nested_enum: TestNestedEnum::OkEmpty },
                t_test_type_vec: vec![TestType{ test_name: "test_name".to_string(), test_int: 1, test_nested_enum: TestNestedEnum::OkEmpty }, TestType{ test_name: "test_name".to_string(), test_int: 1, test_nested_enum: TestNestedEnum::OkEmpty }],
                t_test_type_option: Some(TestType{ test_name: "test_name".to_string(), test_int: 1, test_nested_enum: TestNestedEnum::OkEmpty }),
            });
    }
}

#[reducer]
pub fn start_integration_tests(ctx: &ReducerContext) {
    log::info!("start_integration_tests called");
    ctx.db.test_scheduled_table().insert(TestScheduledTable {
        scheduled_id: 0,
        h1: 1,
        scheduled_at: TimeDuration::from_micros(1000000).into(),
        h2: 1,
        public_count: 0,
        private_count: 0,
    });
    ctx.db.test_no_pk_table().insert(ViewType{ row: 1, name: "Hello World".to_string() });
    ctx.db.test_no_pk_table().insert(ViewType{ row: 2, name: "Hello World2".to_string() });
    ctx.db.test_no_pk_table().insert(ViewType{ row: 3, name: "Hello World3".to_string() });
}

#[reducer]
pub fn clear_integration_tests(ctx: &ReducerContext) -> Result<(),String> {
    log::info!("clear_integration_tests called");
    for row in ctx.db.test_scheduled_table().iter() {
        ctx.db.test_scheduled_table().delete(row);
    }
    for row in ctx.db.test_table_datatypes().iter() {
        ctx.db.test_table_datatypes().delete(row);
    }
    for row in ctx.db.test_no_pk_table().iter(){
        ctx.db.test_no_pk_table().delete(row);
    }
    Ok(())
}

#[reducer]
pub fn reducer_test_parameters(ctx: &ReducerContext, datatypes: TestTableDatatypes, t_u32: u32, t_u64: u64, t_string: String, test_enum: TestEnum, test_nested_enum: TestNestedEnum, t_vec_u32: Vec<u32> ) -> Result<(),String> {
    if !datatypes.t_vec_string.first().eq(&Some(&"hello world".to_string())){
        return Err(format!("ReducerTest: datatypes parameter {} is not 'hello world'", datatypes.t_vec_string.first().unwrap()));
    }
    if t_u32 != 32{
        return Err(format!("ReducerTest: t_u32 parameter {} is not 32", t_u32));
    }
    if t_u64 != 64{
        return Err(format!("ReducerTest: t_u64 parameter {} is not 64", t_u64));
    }
    if !t_string.eq("hello world"){
        return Err(format!("ReducerTest: t_string {} is not 'hello world'", t_string));
    }
    match test_enum{
        TestEnum::A => {},
        TestEnum::B => {},
    }
    match test_nested_enum{
        TestNestedEnum::OkEmpty => {},
        TestNestedEnum::OK(..) => {},
        TestNestedEnum::Err(_) => {}
        TestNestedEnum::InternalError(_) => {}
        TestNestedEnum::Test(_) => {}
    }
    if !t_vec_u32.first().eq(&Some(&32u32)){
        return Err(format!("ReducerTest: t_vec_u32 parameter {} is not '32'", t_vec_u32.first().unwrap()));
    }
    log::info!("ReducerTest: Completed successfully");
    Ok(())
}

#[view(accessor = test_anonymous_all_types, public)]
pub fn view_test_anonymous_all_types(ctx: &AnonymousViewContext) -> Vec<TestTableDatatypes> {
    ctx.db
        .test_table_datatypes()
        .t_u32()
        .filter(0..u32::MAX)
        .collect::<Vec<TestTableDatatypes>>()
}

#[view(accessor = test_first_type_row, public)]
pub fn view_test_first_type_row(ctx: &ViewContext) -> Vec<TestTableDatatypes> {
    if let Some(row) = ctx
        .db
        .test_table_datatypes()
        .t_u32()
        .filter(0..u32::MAX)
        .next()
    {
        vec![row]
    } else {
        vec![]
    }
}

#[view(accessor = test_u32_at_30, public)]
pub fn view_test_u32_at_30(ctx: &AnonymousViewContext) -> Vec<TestTableDatatypes> {
    ctx.db
        .test_table_datatypes()
        .t_u32()
        .filter(30u32)
        .collect::<Vec<TestTableDatatypes>>()
}

#[view(accessor = test_public_scheduled_count, public)]
pub fn view_test_public_scheduled_count(ctx: &ViewContext) -> Vec<TestScheduledTable> {
    if let Some(row) = ctx
        .db
        .test_scheduled_table()
        .get_by_public_count()
        .filter(0..u64::MAX)
        .next()
    {
        vec![TestScheduledTable {
            scheduled_id: row.scheduled_id,
            h1: 1,
            scheduled_at: row.scheduled_at,
            h2: 1,
            public_count: row.public_count,
            private_count: 0,
        }]
    } else {
        vec![]
    }
}

#[view(accessor = test_private_scheduled_count, public)]
pub fn view_test_private_scheduled_count(ctx: &ViewContext) -> Vec<TestScheduledTable> {
    if let Some(row) = ctx
        .db
        .test_scheduled_table()
        .get_by_public_count()
        .filter(0..u64::MAX)
        .next()
    {
        vec![TestScheduledTable {
            scheduled_id: row.scheduled_id,
            h1: 1,
            scheduled_at: row.scheduled_at,
            h2: 1,
            public_count: row.public_count,
            private_count: row.private_count,
        }]
    } else {
        vec![]
    }
}

#[table(accessor = test_no_pk_table)]
pub struct ViewType{
    #[index(btree)]
    pub row: u64,
    pub name: String,
}

#[view(accessor = test_no_pk_option, public)]
pub fn view_test_no_pk_option(ctx: &AnonymousViewContext) -> Option<ViewType>{
    ctx.db.test_no_pk_table().row().filter(0..u64::MAX).next()
}

#[view(accessor = test_no_pk_query, public)]
pub fn view_test_no_pk_query(ctx: &AnonymousViewContext) -> impl Query<ViewType>{
    ctx.from.test_no_pk_table().r#where(|row| row.row.gt(0))
}

#[view(accessor = test_no_pk_vec, public)]
pub fn view_test_no_pk_vec(ctx: &AnonymousViewContext) -> Vec<ViewType>{
    ctx.db.test_no_pk_table().row().filter(0..u64::MAX).collect::<Vec<ViewType>>()
}


#[view(accessor = test_option, public)]
pub fn view_test_option(ctx:&ViewContext)-> Option<TestScheduledTable>{
    ctx.db.test_scheduled_table().get_by_public_count().filter(5u64..100u64).next()
}

#[view(accessor = test_query, public)]
pub fn view_test_query(ctx:&ViewContext)-> impl Query<TestScheduledTable>{
    ctx.from.test_scheduled_table().r#where(|row| row.h1.gt(1))
}


#[procedure]
pub fn procedure_test_option_return(
    ctx: &mut ProcedureContext,
    t_u64: u64,
) -> Option<TestTableDatatypes> {

    if let Some(row) = ctx.with_tx(|tctx| tctx.db.test_table_datatypes().t_u64().find(t_u64)){
        return Some(row);
    }
    None
}

#[procedure]
pub fn procedure_test_vec_return(
    ctx: &mut ProcedureContext,
    t_u64: u64,
) -> Vec<TestTableDatatypes> {

    if let Some(row) = ctx.with_tx(|tctx| tctx.db.test_table_datatypes().t_u64().find(t_u64)){
        return vec![row];
    }
    vec![]
}

#[procedure]
pub fn procedure_test_type_return(
    ctx: &mut ProcedureContext,
    t_u64: u64,
) -> TestTableDatatypes {

    if let Some(row) = ctx.with_tx(|tctx| tctx.db.test_table_datatypes().t_u64().find(t_u64)){
        return row;
    }
    TestTableDatatypes::default()
}

#[procedure]
pub fn procedure_test_result_return(
    ctx: &mut ProcedureContext,
    t_u64: u64,
) -> Result<TestTableDatatypes, String> {

    if let Some(row) = ctx.with_tx(|tctx| tctx.db.test_table_datatypes().t_u64().find(t_u64)){
        return Ok(row);
    }
    return Err(format!("row {} not found", t_u64));
}

#[table(accessor = test_event_table, public, event)]
pub struct TestEventTable{
    #[primary_key]
    pub id: u32,
    #[unique]
    pub id2:u32

}

#[reducer]
pub fn trigger_event(ctx:&ReducerContext){
    ctx.db.test_event_table().insert(TestEventTable{ id: 1, id2: 1 });
}