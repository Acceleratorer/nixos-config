// SPDX-FileCopyrightText: 2022 Harish Rajagopal <harish.rajagopals@gmail.com>
//
// SPDX-License-Identifier: GPL-3.0-or-later

//! Templates for various GUI components
#![allow(dead_code)] // Silence dead code warnings for UI code that isn't dead

use gtk::prelude::*;
use relm4::{gtk, WidgetTemplate};

/// Button that ends the greeter (eg. Reboot)
#[relm4::widget_template(pub)]
impl WidgetTemplate for EndButton {
    view! {
        gtk::Button {
            set_focusable: true,
            add_css_class: "destructive-action",
        }
    }
}

/// Label for an entry/combo box
#[relm4::widget_template(pub)]
impl WidgetTemplate for EntryLabel {
    view! {
        gtk::Label {
            set_width_request: 100,
            set_xalign: 1.0,
        }
    }
}

/// Main UI of the greeter
#[relm4::widget_template(pub)]
impl WidgetTemplate for Ui {
    view! {
        gtk::Overlay {
            set_width_request: 1920,
            set_height_request: 1080,

            /// Precomposed Hyprlock wallpaper, static overlay, and avatar.
            #[name = "background"]
            gtk::Picture,

            /// Recovery-only user and session chooser.
            #[name = "selection_frame"]
            add_overlay = &gtk::Frame {
                set_halign: gtk::Align::Center,
                set_valign: gtk::Align::Center,
                add_css_class: "cryoforge-selection-frame",

                gtk::Grid {
                    set_column_spacing: 15,
                    set_margin_bottom: 15,
                    set_margin_end: 15,
                    set_margin_start: 15,
                    set_margin_top: 15,
                    set_row_spacing: 15,
                    set_width_request: 500,

                    /// Widget to display messages to the user.
                    #[name = "message_label"]
                    attach[0, 0, 3, 1] = &gtk::Label {
                        set_margin_bottom: 15,

                        #[wrap(Some)]
                        set_attributes = &gtk::pango::AttrList {
                            insert: {
                                let mut font_desc = gtk::pango::FontDescription::new();
                                font_desc.set_weight(gtk::pango::Weight::Bold);
                                gtk::pango::AttrFontDesc::new(&font_desc)
                            },
                        },
                    },

                    #[template]
                    attach[0, 1, 1, 1] = &EntryLabel {
                        set_label: "User:",
                        set_height_request: 45,
                    },

                    #[name = "session_label"]
                    #[template]
                    attach[0, 2, 1, 1] = &EntryLabel {
                        set_label: "Session:",
                        set_height_request: 45,
                    },

                    #[name = "usernames_box"]
                    attach[1, 1, 1, 1] = &gtk::ComboBoxText {
                        set_hexpand: true,
                    },

                    #[name = "username_entry"]
                    attach[1, 1, 1, 1] = &gtk::Entry {
                        set_hexpand: true,
                    },

                    #[name = "sessions_box"]
                    attach[1, 2, 1, 1] = &gtk::ComboBoxText,

                    #[name = "session_entry"]
                    attach[1, 2, 1, 1] = &gtk::Entry,

                    #[name = "user_toggle"]
                    attach[2, 1, 1, 1] = &gtk::ToggleButton {
                        set_icon_name: "document-edit-symbolic",
                        set_tooltip_text: Some("Manually enter username"),
                    },

                    #[name = "sess_toggle"]
                    attach[2, 2, 1, 1] = &gtk::ToggleButton {
                        set_icon_name: "document-edit-symbolic",
                        set_tooltip_text: Some("Manually enter session command"),
                    },

                    attach[1, 3, 2, 1] = &gtk::Box {
                        set_halign: gtk::Align::End,
                        set_spacing: 15,

                        #[name = "cancel_button"]
                        gtk::Button {
                            set_visible: false,
                            set_label: "Cancel",
                        },

                        #[name = "login_button"]
                        gtk::Button {
                            set_focusable: true,
                            set_label: "Login",
                            set_receives_default: true,
                            add_css_class: "suggested-action",
                        },
                    },
                },
            },

            /// Invisible native secret entry. Custom dots render above it.
            #[name = "secret_entry"]
            add_overlay = &gtk::PasswordEntry {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 839,
                set_margin_top: 713,
                set_width_request: 306,
                set_height_request: 44,
                set_show_peek_icon: false,
                add_css_class: "cryoforge-secret",
            },

            /// Visible authentication input for non-password PAM prompts.
            #[name = "visible_entry"]
            add_overlay = &gtk::Entry {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 839,
                set_margin_top: 713,
                set_width_request: 306,
                set_height_request: 44,
                add_css_class: "cryoforge-visible",
            },

            /// Centered Hyprlock-style password dots.
            #[name = "password_dots"]
            add_overlay = &gtk::DrawingArea {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 839,
                set_margin_top: 725,
                set_width_request: 306,
                set_height_request: 20,
                set_can_target: false,
            },

            /// Empty and failure text share the baked password lane.
            #[name = "password_prompt"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 839,
                set_margin_top: 725,
                set_width_request: 306,
                set_height_request: 20,
                set_xalign: 0.5,
                set_yalign: 0.5,
                set_can_target: false,
                add_css_class: "cryoforge-password-prompt",
            },

            /// Live clock aligned with the current Hyprlock widget.
            #[name = "clock_frame"]
            add_overlay = &gtk::Frame {
                set_halign: gtk::Align::Center,
                set_valign: gtk::Align::Start,
                set_margin_top: 296,
                set_width_request: 360,
                set_height_request: 164,
                add_css_class: "cryoforge-clock-frame",
            },

            #[name = "date_label"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Center,
                set_valign: gtk::Align::Start,
                set_margin_top: 436,
                set_width_request: 360,
                set_height_request: 28,
                set_xalign: 0.5,
                add_css_class: "cryoforge-date",
            },

            /// Soft, non-interactive anime microcopy around the baked avatar.
            add_overlay = &gtk::Label {
                set_label: "nyaa~",
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 1050,
                set_margin_top: 548,
                set_width_request: 80,
                set_height_request: 20,
                set_xalign: 0.5,
                set_can_target: false,
                add_css_class: "cryoforge-anime-accent",
            },

            add_overlay = &gtk::Label {
                set_label: "おかえり",
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 780,
                set_margin_top: 625,
                set_width_request: 90,
                set_height_request: 20,
                set_xalign: 0.5,
                set_can_target: false,
                add_css_class: "cryoforge-anime-whisper",
            },

            #[name = "top_battery_label"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 1216,
                set_margin_top: 344,
                set_width_request: 80,
                set_height_request: 30,
                set_xalign: 0.5,
                add_css_class: "cryoforge-top-value",
            },

            #[name = "top_network_label"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 1308,
                set_margin_top: 340,
                set_width_request: 100,
                set_height_request: 30,
                set_xalign: 0.5,
                add_css_class: "cryoforge-top-value",
                add_css_class: "cryoforge-top-network",
            },

            #[name = "right_network_label"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 1350,
                set_margin_top: 600,
                set_width_request: 120,
                set_height_request: 30,
                set_xalign: 1.0,
                add_css_class: "cryoforge-right-value",
            },

            #[name = "right_power_label"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 1390,
                set_margin_top: 665,
                set_width_request: 80,
                set_height_request: 30,
                set_xalign: 1.0,
                add_css_class: "cryoforge-right-value",
            },

            #[name = "right_uptime_label"]
            add_overlay = &gtk::Label {
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::Start,
                set_margin_start: 1370,
                set_margin_top: 724,
                set_width_request: 100,
                set_height_request: 30,
                set_xalign: 1.0,
                add_css_class: "cryoforge-right-value",
            },

            /// Visible escape hatch to the native user/session chooser.
            #[name = "recovery_button"]
            add_overlay = &gtk::Button {
                set_label: "SESSION · RECOVERY",
                set_tooltip_text: Some("Choose GNOME or another session (Esc)"),
                set_halign: gtk::Align::Start,
                set_valign: gtk::Align::End,
                set_margin_start: 24,
                set_margin_bottom: 24,
                set_width_request: 190,
                set_height_request: 44,
                set_focusable: true,
                add_css_class: "cryoforge-recovery-button",
            },

            /// Recovery-only error and power actions.
            #[name = "end_controls"]
            add_overlay = &gtk::Box {
                set_orientation: gtk::Orientation::Vertical,
                set_halign: gtk::Align::Center,
                set_valign: gtk::Align::End,
                set_margin_bottom: 15,
                set_spacing: 15,

                gtk::Frame {
                    #[name = "error_info"]
                    gtk::InfoBar {
                        set_visible: false,
                        set_message_type: gtk::MessageType::Error,

                        #[name = "error_label"]
                        gtk::Label {
                            set_halign: gtk::Align::Center,
                            set_margin_top: 10,
                            set_margin_bottom: 10,
                            set_margin_start: 10,
                            set_margin_end: 10,
                        },
                    }
                },

                gtk::Box {
                    set_halign: gtk::Align::Center,
                    set_homogeneous: true,
                    set_spacing: 15,

                    #[name = "reboot_button"]
                    #[template]
                    EndButton {
                        set_label: "Reboot",
                    },

                    #[name = "poweroff_button"]
                    #[template]
                    EndButton {
                        set_label: "Power Off",
                    },
                },
            },
        }
    }
}
