use spacetimedb::*;

#[derive(Debug, SpacetimeType, Clone, Default)]
pub enum TestEnum {
    #[default]
    A,
    B,
}

#[derive(Debug, SpacetimeType, Clone, Default)]
pub struct  TestType {
    pub test_name : String,
    pub test_int: u64,
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
            t_test_type: TestType{ test_name: "test_name".to_string(), test_int: 1 },
            t_test_type_vec: vec![TestType{ test_name: "test_name".to_string(), test_int: 1 }],
            t_test_type_option: Some(TestType{ test_name: "test_name".to_string(), test_int: 1 }),
        }
    }
}

#[table(accessor = test_scheduled_table, public, scheduled(test_scheduled_reducer), index(accessor = get_by_public_count, btree(columns = [public_count])))]
pub struct TestScheduledTable {
    #[primary_key]
    #[auto_inc]
    pub scheduled_id: u64,
    pub h1: u16,
    pub scheduled_at: spacetimedb::ScheduleAt,
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
                t_test_type: TestType{ test_name: "test_name".to_string(), test_int: 1 },
                t_test_type_vec: vec![TestType{ test_name: "test_name".to_string(), test_int: 1 }, TestType{ test_name: "test_name".to_string(), test_int: 1 }],
                t_test_type_option: Some(TestType{ test_name: "test_name".to_string(), test_int: 1 }),
            });
    }
}

#[reducer]
pub fn start_integration_tests(ctx: &ReducerContext) {
    ctx.db.test_scheduled_table().insert(TestScheduledTable {
        scheduled_id: 0,
        h1: 1,
        scheduled_at: TimeDuration::from_micros(1000000).into(),
        h2: 1,
        public_count: 0,
        private_count: 0,
    });
    ctx.db.test_no_pk_table().insert(ViewType{ row: 1, name: "Hello World".to_string() });
    // ctx.db.test_table_datatypes().insert(TestTableDatatypes {
    //     t_u64: 0,
    //     t_u8: u8::MAX,
    //     t_u16: u16::MAX,
    //     t_u32: u32::MAX,
    //     t_u128: u128::MAX,
    //     t_f32: f32::MAX,
    //     t_f64: f64::MAX,
    //     t_i8: i8::MAX,
    //     t_i16: i16::MAX,
    //     t_i32: i32::MAX,
    //     t_i64: i64::MAX,
    //     //t_i128: i128::MAX,
    //     t_string: "a String example that is some text to decode.".to_string(),
    //     t_vec_string: vec![
    //         "a string inside a vec that needs to be decoded.".to_string(),
    //         "another text in the vec to be decoded".to_string(),
    //     ],
    //     t_vec_u64: (0..20).collect(),
    //     t_opt_string: Some("Some option String to decode".to_string()),
    //     t_opt_u64: Some(u64::MAX),
    // });
}

#[reducer]
pub fn clear_integration_tests(ctx: &ReducerContext) {
    for row in ctx.db.test_scheduled_table().iter() {
        ctx.db.test_scheduled_table().delete(row);
    }
    for row in ctx.db.test_table_datatypes().iter() {
        ctx.db.test_table_datatypes().delete(row);
    }
    for row in ctx.db.test_no_pk_table().iter(){
        ctx.db.test_no_pk_table().delete(row);
    }
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
    ctx.from.test_scheduled_table().r#where(|row| row.h1.eq(1))
}

#[procedure]
pub fn procedure_test_get_table_datatypes_row(
    ctx: &mut ProcedureContext,
    t_u64: u64,
) -> Option<TestTableDatatypes> {
    if let Some(row) = ctx.with_tx(|tctx| tctx.db.test_table_datatypes().t_u64().find(t_u64)){
        return Some(row);
    }
    None
}
