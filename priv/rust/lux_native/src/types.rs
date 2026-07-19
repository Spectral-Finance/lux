use rustler::Term;

pub fn inspect_term_type(term: Term) -> String {
    if term.is_atom() {
        "atom".to_string()
    } else if term.is_binary() {
        "binary".to_string()
    } else if term.is_number() {
        "number".to_string()
    } else if term.is_list() {
        "list".to_string()
    } else if term.is_map() {
        "map".to_string()
    } else if term.is_tuple() {
        "tuple".to_string()
    } else if term.is_pid() {
        "pid".to_string()
    } else if term.is_port() {
        "port".to_string()
    } else if term.is_ref() {
        "reference".to_string()
    } else if term.is_fun() {
        "function".to_string()
    } else {
        "unknown".to_string()
    }
}
