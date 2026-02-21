pub mod main_types;

use main_types::color::Color;
use main_types::lobby::{assign_user_to_lobby, user_disconnected};
use main_types::vectors::{Vector2, Vector3, Vector4};

use spacetimedb::SpacetimeType;
use spacetimedb::{
    rand::{seq::SliceRandom, Rng},
    reducer, table, Identity, ReducerContext, Table, Timestamp,
};

const PLAYER_SPEED: f32 = 10.0;

#[table(accessor = user, public)]
#[table(accessor = user_next, public)]
pub struct User {
    #[primary_key]
    pub identity: Identity,
    pub online: bool,
    pub lobby_id: u64,
    pub damage: Damage,
    pub test_option_string: Option<Vec<String>>,
    pub test_option_message: Option<Message>,
}
#[derive(SpacetimeType, Debug)]
pub struct Damage {
    pub amount: u32,
    pub source: Identity,
    pub int_vec: Vec<u8>,
}

#[derive(SpacetimeType, Debug)]
pub struct Message {
    pub int_value: u8,
    pub string_value: String,
    pub int_vec: Vec<u8>,
    pub string_vec: Vec<String>,
    pub test_option: Option<String>,
    pub test_option_vec: Option<Vec<String>>,
    pub test_inner: Option<Damage>,
}

#[table(accessor = user_data, public)]
#[table(accessor = user_data_hidden)]
pub struct UserData {
    #[primary_key]
    pub identity: Identity,
    pub online: bool,
    pub name: String,
    pub lobby_id: u64,
    pub color: Color,
    pub test_vec: Vec<String>,
    pub test_bytes_array: Vec<u8>,
    pub test_dynamic_arraylike: Vector4,
    pub last_position: Vector3,
    pub direction: Vector2,
    pub player_speed: f32,
    pub last_update: Timestamp,
}

#[reducer(client_connected)]
pub fn client_connected(ctx: &ReducerContext) {
    if let Some(user) = ctx.db.user().identity().find(ctx.sender()) {
        if let Some(connection_id) = ctx.connection_id() {
            log::info!("ConnectionID : {}", connection_id);
        }

        if user.lobby_id == 0 {
            assign_user_to_lobby(ctx, ctx.sender());
        }
    } else {
        let new_name = get_random_name(&ctx);
        let mut new_int_vec = Vec::new();
        new_int_vec.push(10);
        new_int_vec.push(20);

        let mut string_vec = Vec::new();
        for i in 0..50 {
            string_vec.push(format!("String {}", i));
        }

        let test_damage: Damage = Damage {
            amount: 16,
            source: ctx.sender(),
            int_vec: new_int_vec.clone(),
        };
        let test_message = Message {
            int_value: 26,
            string_value: "Jupiter".to_owned(),
            int_vec: new_int_vec.clone(),
            string_vec: string_vec.clone(),
            test_option: None,
            test_inner: Some(test_damage),
            test_option_vec: Some(string_vec.clone()),
        };
        ctx.db.user().insert(User {
            identity: ctx.sender(),
            online: true,
            lobby_id: 0,
            damage: Damage {
                amount: 0,
                source: ctx.sender(),
                int_vec: new_int_vec,
            },
            test_option_string: Some(string_vec),
            test_option_message: Some(test_message),
        });

        let mut test_vec = Vec::new();
        test_vec.push("one".to_string());
        test_vec.push("two".to_string());
        test_vec.push("three".to_string());

        ctx.db.user_data().insert(UserData {
            identity: ctx.sender(),
            online: true,
            name: new_name.clone(),
            lobby_id: 0,
            color: Color::random(&ctx),
            test_vec,
            test_bytes_array: Vec::new(),
            test_dynamic_arraylike: Vector4 { x: 1.2, y: 3.4, z: 5.6, w: 7.8 },
            last_position: Vector3::get_random_position(&ctx),
            player_speed: PLAYER_SPEED,
            direction: Vector2 { x: 0.0, y: 0.0 },
            last_update: ctx.timestamp,
        });

        if let Some(connection_id) = ctx.connection_id() {
            log::info!("ConnectionID : {}", connection_id);
        }

        log::info!("New user {} : online", new_name);

        assign_user_to_lobby(ctx, ctx.sender());
    }
}

#[reducer(client_disconnected)]
pub fn client_disconnected(ctx: &ReducerContext) {
    if let Some(user) = ctx.db.user().identity().find(ctx.sender()) {
        let lobby_id = user.lobby_id.clone();

        ctx.db.user().identity().update(User {
            online: false,
            lobby_id: 0, //remove lobby id when disconnected
            ..user
        });

        if let Some(user_data) = ctx.db.user_data().identity().find(ctx.sender()) {
            let name = user_data.name.clone();

            ctx.db.user_data().identity().update(UserData {
                lobby_id: 0,
                online: false,
                ..user_data
            });
            log::info!(
                "Reset UserData lobby_id for disconnected user {:?}. User {} offline",
                ctx.sender(),
                name
            );
        } else {
            // This branch should be unreachable
            log::warn!("UserData not found for disconnecting user {:?}", ctx.sender());
        }

        if lobby_id != 0 {
            //Decrease lobby players count from lobby table
            user_disconnected(&ctx, lobby_id);
        }
    } else {
        // This branch should be unreachable
        log::warn!(
            "Disconnect event for unknown user with identity {:?}",
            ctx.sender()
        );
    }
}

pub fn get_random_name(ctx: &ReducerContext) -> String {
    let possible_names = ["Will", "Espresso", "Joker", "ChatGPT", "Gemini"];
    let mut rng = ctx.rng();
    if let Some(name) = possible_names.choose(&mut rng) {
        return String::from(*name);
    } else {
        return String::from("Popa");
    }
}

#[reducer]
pub fn test_struct(
    ctx: &ReducerContext,
    message: Message,
    //another_message: Message,
) -> Result<(), String> {
    let mut int_vec = Vec::new();
    int_vec.push(1);
    int_vec.push(2);
    int_vec.push(3);

    let mut string_vec = Vec::new();
    string_vec.push(String::from("One"));
    string_vec.push(String::from("Two"));
    string_vec.push(String::from("Three"));

    let formatted = format!("{:?}", message);
    //let formatted_second = format!("{:?}", another_message);
    //log::info!("{}, another : {}", formatted, formatted_second);
    Err(format!("{}", formatted))
}
#[reducer]
pub fn test_option_vec(ctx: &ReducerContext, option: Option<Vec<String>>) -> Result<(), String> {
    Err(format!("{:?}", option))
}

#[reducer]
pub fn test_option_single(ctx: &ReducerContext, option: Option<String>) -> Result<(), String> {
    Err(format!("{:?}", option))
}
#[reducer]
pub fn save_my_bytes(ctx: &ReducerContext, bytes: Vec<u8>) {
    if let Some(mut user_data) = ctx.db.user_data().identity().find(ctx.sender()) {
        log::info!("{}", bytes.len());
        user_data.test_bytes_array = bytes;
        ctx.db.user_data().identity().update(user_data);
        log::info!("Writed!");
    }
}

#[reducer]
pub fn change_color_random(ctx: &ReducerContext) {
    if let Some(user) = ctx.db.user_data().identity().find(ctx.sender()) {
        // --- Update User State ---
        ctx.db.user_data().identity().update(UserData {
            color: Color::random(ctx),
            ..user
        });
    }
}
#[reducer]
pub fn move_user(
    ctx: &ReducerContext,
    new_input: Vector2,
    global_position: Vector3,
) -> Result<(), String> {
    let current_time = ctx.timestamp;

    if let Some(user) = ctx.db.user_data().identity().find(ctx.sender()) {
        // --- Update User State ---
        ctx.db.user_data().identity().update(UserData {
            last_position: global_position,
            direction: new_input,
            player_speed: PLAYER_SPEED,
            last_update: current_time,
            ..user
        });

        Ok(())
    } else {
        Err(format!("User not found!"))
    }
}

#[spacetimedb::reducer(init)]
pub fn init(ctx: &ReducerContext) {
    //log::info!("Start Invoke");
}
