extern crate proc_macro;
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, ItemFn, Meta, Expr};

#[proc_macro_attribute]
pub fn lux_component(args: TokenStream, input: TokenStream) -> TokenStream {
    let input_fn = parse_macro_input!(input as ItemFn);
    
    // Parse arguments manually using syn 2.0 patterns
    let attr_args = parse_macro_input!(args with syn::punctuated::Punctuated::<Meta, syn::Token![,]>::parse_terminated);

    let fn_name = &input_fn.sig.ident;
    let mut component_name = fn_name.to_string();
    let mut description = String::new();
    let mut input_schema = String::from("{}");
    let mut output_schema = String::from("{}");

    for meta in attr_args {
        if let Meta::NameValue(nv) = meta {
            if nv.path.is_ident("name") {
                if let Expr::Lit(expr_lit) = nv.value {
                    if let syn::Lit::Str(lit) = expr_lit.lit {
                        component_name = lit.value();
                    }
                }
            } else if nv.path.is_ident("description") {
                if let Expr::Lit(expr_lit) = nv.value {
                    if let syn::Lit::Str(lit) = expr_lit.lit {
                        description = lit.value();
                    }
                }
            } else if nv.path.is_ident("input_schema") {
                if let Expr::Lit(expr_lit) = nv.value {
                    if let syn::Lit::Str(lit) = expr_lit.lit {
                        input_schema = lit.value();
                    }
                }
            } else if nv.path.is_ident("output_schema") {
                if let Expr::Lit(expr_lit) = nv.value {
                    if let syn::Lit::Str(lit) = expr_lit.lit {
                        output_schema = lit.value();
                    }
                }
            }
        }
    }

    let expanded = quote! {
        #input_fn

        #[allow(non_upper_case_globals)]
        inventory::submit! {
            crate::ComponentRegistration {
                name: #component_name,
                description: #description,
                input_schema: #input_schema,
                output_schema: #output_schema,
                handler: #fn_name,
            }
        }
    };

    TokenStream::from(expanded)
}
