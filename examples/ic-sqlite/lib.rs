#![deny(rust_2018_idioms)]

use ic_cdk::api::trap;
use ic_cdk::api::call::call;
use ic_cdk::export::Principal;
use ic_cdk_macros::{init, update};
use ic_sqlite::Connection;
use rand_chacha::ChaCha20Rng;
use rand_core::SeedableRng;
use std::convert::TryInto;

thread_local! {
    static CSPRNG: Option<ChaCha20Rng> = None;
    // static CONNECTION: Option<Connection> = None;
}

#[init]
fn init() {
    ic_cdk::println!("Init")
}

// Based on https://github.com/dfinity/internet-identity/blob/b2a87609cea944c12ca75097048a545a5dc2bbe7/src/internet_identity/src/main.rs#L665-L679
async fn make_rng() -> rand_chacha::ChaCha20Rng {
    let raw_rand: Vec<u8> = match call(Principal::management_canister(), "raw_rand", ()).await {
        Ok((res,)) => res,
        Err((_, err)) => trap(&format!("failed to get salt: {}", err)),
    };
    let seed: [u8; 32] = raw_rand[..].try_into().unwrap_or_else(|_| {
        trap(&format!(
            "expected raw randomness to be of length 32, got {}",
            raw_rand.len()
        ));
    });

    rand_chacha::ChaCha20Rng::from_seed(seed)
}

#[update]
async fn sqlite3_os_init() {
    let rng = make_rng().await;
    ic_sqlite::vfs::RNG.with(|rng_ref| rng_ref.replace(Some(rng)));
    ic_sqlite::sqlite3_os_init();
}

// #[update]
// fn conn_new() {
//     ic_sqlite::conn_new();
// }

// #[update]
// fn conn_execute() {
//     ic_sqlite::conn_execute();
// }

// #[update]
// fn conn_query() {
//     ic_sqlite::conn_query();
// }
