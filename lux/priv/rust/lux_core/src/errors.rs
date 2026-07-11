use rustler::{Atom, Env, Term, Encoder};
use rustler::Error as RustlerError;

rustler::atoms! {
    ok,
    error,
    // Error reasons
    invalid_type,
    conversion_failed,
    internal_error,
}

/// Helper macro to return a standard `{:ok, value}` tuple
#[macro_export]
macro_rules! ok_tuple {
    ($env:expr, $val:expr) => {
        Ok(rustler::types::tuple::make_tuple($env, &[
            $crate::errors::ok().encode($env),
            $val.encode($env),
        ]))
    };
}

/// Helper macro to return a standard `{:error, reason}` tuple
#[macro_export]
macro_rules! error_tuple {
    ($env:expr, $reason:expr) => {
        Ok(rustler::types::tuple::make_tuple($env, &[
            $crate::errors::error().encode($env),
            $reason.encode($env),
        ]))
    };
}

/// Formats a string error into a rustler error term
pub fn format_error<'a>(env: Env<'a>, message: &str) -> Term<'a> {
    rustler::types::tuple::make_tuple(env, &[
        error().encode(env),
        message.encode(env)
    ])
}
