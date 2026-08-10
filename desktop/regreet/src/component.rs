// SPDX-FileCopyrightText: 2022 Harish Rajagopal <harish.rajagopals@gmail.com>
//
// SPDX-License-Identifier: GPL-3.0-or-later

//! Setup for using the greeter as a Relm4 component

use std::{fs, path::PathBuf};

use jiff::{civil::Weekday, tz::TimeZone, Timestamp, Zoned};
use relm4::{
    component::{AsyncComponent, AsyncComponentParts},
    gtk::{gdk, glib, prelude::*},
    prelude::*,
    AsyncComponentSender,
};
use tracing::{debug, info, warn};

#[cfg(feature = "gtk4_8")]
use crate::config::BgFit;

use super::messages::{CommandMsg, InputMsg, UserSessInfo};
use super::model::{Greeter, InputMode, Updates};
use super::templates::Ui;

/// Load GTK settings from the greeter config.
fn setup_settings(model: &Greeter, root: &gtk::ApplicationWindow) {
    let settings = root.settings();
    let config = if let Some(config) = model.config.get_gtk_settings() {
        config
    } else {
        return;
    };

    debug!(
        "Setting dark theme: {}",
        config.application_prefer_dark_theme
    );
    settings.set_gtk_application_prefer_dark_theme(config.application_prefer_dark_theme);

    if let Some(cursor_theme) = &config.cursor_theme_name {
        debug!("Setting cursor theme: {cursor_theme}");
        settings.set_gtk_cursor_theme_name(config.cursor_theme_name.as_deref());
    };

    debug!("Setting cursor blink: {}", config.cursor_blink);
    settings.set_gtk_cursor_blink(config.cursor_blink);

    if let Some(font) = &config.font_name {
        debug!("Setting font: {font}");
        settings.set_gtk_font_name(config.font_name.as_deref());
    };

    if let Some(icon_theme) = &config.icon_theme_name {
        debug!("Setting icon theme: {icon_theme}");
        settings.set_gtk_icon_theme_name(config.icon_theme_name.as_deref());
    };

    if let Some(theme) = &config.theme_name {
        debug!("Setting theme: {theme}");
        settings.set_gtk_theme_name(config.theme_name.as_deref());
    };
}

/// Populate the user and session combo boxes with entries.
fn setup_users_sessions(model: &Greeter, widgets: &GreeterWidgets) {
    let mut initial_username = model.config.get_default_user().map(str::to_string);

    for (user, username) in model.sys_util.get_users().iter() {
        debug!("Found user: {user}");
        if initial_username.is_none() {
            initial_username = Some(username.clone());
        }
        widgets.ui.usernames_box.append(Some(username), user);
    }

    for session in model.sys_util.get_sessions().keys() {
        debug!("Found session: {session}");
        widgets.ui.sessions_box.append(Some(session), session);
    }

    if model.config.get_default_user().is_none() {
        if let Some(last_user) = model.cache.get_last_user() {
            initial_username = Some(last_user.to_string());
        } else if let Some(user) = &initial_username {
            info!("Using first found user '{user}' as initial user");
        }
    }

    if let Some(session) = model.config.get_default_session() {
        if !widgets.ui.sessions_box.set_active_id(Some(session)) {
            warn!("Couldn't find session '{session}' to set as the initial session");
        }
    }

    if !widgets
        .ui
        .usernames_box
        .set_active_id(initial_username.as_deref())
    {
        if let Some(user) = initial_username {
            warn!("Couldn't find user '{user}' to set as the initial user");
        }
    }

    // A username change can restore a cached session. The configured default
    // is authoritative for the single-user fast path.
    if let Some(session) = model.config.get_default_session() {
        widgets.ui.sessions_box.set_active_id(Some(session));
    }
}

fn set_letter_spacing(label: &gtk::Label, spacing: i32) {
    let attrs = gtk::pango::AttrList::new();
    attrs.insert(gtk::pango::AttrInt::new_letter_spacing(spacing));
    label.set_attributes(Some(&attrs));
}

fn date_text() -> String {
    let now = Zoned::new(Timestamp::now(), TimeZone::system());
    let weekday = match now.weekday() {
        Weekday::Monday => "MONDAY",
        Weekday::Tuesday => "TUESDAY",
        Weekday::Wednesday => "WEDNESDAY",
        Weekday::Thursday => "THURSDAY",
        Weekday::Friday => "FRIDAY",
        Weekday::Saturday => "SATURDAY",
        Weekday::Sunday => "SUNDAY",
    };
    let month = match now.month() {
        1 => "JANUARY",
        2 => "FEBRUARY",
        3 => "MARCH",
        4 => "APRIL",
        5 => "MAY",
        6 => "JUNE",
        7 => "JULY",
        8 => "AUGUST",
        9 => "SEPTEMBER",
        10 => "OCTOBER",
        11 => "NOVEMBER",
        12 => "DECEMBER",
        _ => "UNKNOWN",
    };
    format!("{weekday} · {month} {:02}", now.day())
}

fn battery_text() -> String {
    fs::read_to_string("/sys/class/power_supply/BAT0/capacity")
        .ok()
        .map(|value| format!("{}%", value.trim()))
        .unwrap_or_else(|| "--".into())
}

fn network_connected() -> bool {
    fs::read_dir("/sys/class/net")
        .ok()
        .into_iter()
        .flatten()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_name() != "lo")
        .any(|entry| {
            fs::read_to_string(entry.path().join("operstate"))
                .map(|state| state.trim() == "up")
                .unwrap_or(false)
        })
}

fn uptime_text() -> String {
    let Some(seconds) = fs::read_to_string("/proc/uptime")
        .ok()
        .and_then(|value| value.split_whitespace().next().map(str::to_string))
        .and_then(|value| value.split('.').next().map(str::to_string))
        .and_then(|value| value.parse::<u64>().ok())
    else {
        return "--".into();
    };

    let days = seconds / 86_400;
    let hours = (seconds % 86_400) / 3_600;
    let minutes = (seconds % 3_600) / 60;

    if days > 0 {
        format!("{days:02}D {hours:02}H")
    } else {
        format!("{hours:02}H {minutes:02}M")
    }
}

fn refresh_status_labels(
    date: &gtk::Label,
    top_battery: &gtk::Label,
    top_network: &gtk::Label,
    right_network: &gtk::Label,
    right_power: &gtk::Label,
    right_uptime: &gtk::Label,
) {
    let battery = battery_text();
    let connected = network_connected();

    date.set_label(&date_text());
    top_battery.set_label(&battery);
    top_network.set_label(if connected { "ONLINE" } else { "OFFLINE" });
    right_network.set_label(if connected {
        "CONNECTED"
    } else {
        "DISCONNECTED"
    });
    right_power.set_label(&battery);
    right_uptime.set_label(&uptime_text());
}

/// The info required to initialize the greeter.
pub struct GreeterInit {
    pub config_path: PathBuf,
    pub css_path: PathBuf,
    pub demo: bool,
}

#[relm4::component(pub, async)]
impl AsyncComponent for Greeter {
    type Input = InputMsg;
    type Output = ();
    type Init = GreeterInit;
    type CommandOutput = CommandMsg;

    view! {
        #[name = "window"]
        gtk::ApplicationWindow {
            set_visible: true,

            #[name = "ui"]
            #[template]
            Ui {
                #[template_child]
                background {
                    set_filename: model.config.get_background(),
                },

                #[template_child]
                selection_frame {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: !model.updates.is_input(),
                },

                #[template_child]
                clock_frame {
                    model.clock.widget(),
                },

                #[template_child]
                message_label {
                    #[track(model.updates.changed(Updates::message()))]
                    set_label: &model.updates.message,
                },

                #[template_child]
                session_label {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: !model.updates.is_input(),
                },

                #[template_child]
                usernames_box {
                    #[track(
                        model.updates.changed(Updates::manual_user_mode())
                        || model.updates.changed(Updates::input_mode())
                    )]
                    set_sensitive: !model.updates.manual_user_mode && !model.updates.is_input(),
                    #[track(model.updates.changed(Updates::manual_user_mode()))]
                    set_visible: !model.updates.manual_user_mode,
                    connect_changed[
                        sender,
                        username_entry = ui.username_entry.clone(),
                        sessions_box = ui.sessions_box.clone(),
                        session_entry = ui.session_entry.clone(),
                    ] => move |this| sender.input(
                        Self::Input::UserChanged(
                            UserSessInfo::extract(
                                this,
                                &username_entry,
                                &sessions_box,
                                &session_entry,
                            )
                        )
                    ),
                },

                #[template_child]
                username_entry {
                    #[track(
                        model.updates.changed(Updates::manual_user_mode())
                        || model.updates.changed(Updates::input_mode())
                    )]
                    set_sensitive: model.updates.manual_user_mode && !model.updates.is_input(),
                    #[track(model.updates.changed(Updates::manual_user_mode()))]
                    set_visible: model.updates.manual_user_mode,
                },

                #[template_child]
                sessions_box {
                    #[track(
                        model.updates.changed(Updates::manual_sess_mode())
                        || model.updates.changed(Updates::input_mode())
                    )]
                    set_visible: !model.updates.manual_sess_mode && !model.updates.is_input(),
                    #[track(model.updates.changed(Updates::active_session_id()))]
                    set_active_id: model.updates.active_session_id.as_deref(),
                },

                #[template_child]
                session_entry {
                    #[track(
                        model.updates.changed(Updates::manual_sess_mode())
                        || model.updates.changed(Updates::input_mode())
                    )]
                    set_visible: model.updates.manual_sess_mode && !model.updates.is_input(),
                },

                #[template_child]
                password_dots {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: model.updates.input_mode == InputMode::Secret,
                },

                #[template_child]
                password_prompt {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: model.updates.input_mode == InputMode::Secret,
                    #[track(model.updates.changed(Updates::error()))]
                    set_markup: if model.updates.error.is_some() {
                        "<span foreground=\"#a96878\">もう一度おねがい</span>"
                    } else {
                        "パスワードをどうぞ"
                    },
                },

                #[template_child]
                secret_entry {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: model.updates.input_mode == InputMode::Secret,
                    #[track(
                        model.updates.changed(Updates::input_mode())
                        && model.updates.input_mode == InputMode::Secret
                    )]
                    grab_focus: (),
                    #[track(model.updates.changed(Updates::input()))]
                    set_text: &model.updates.input,
                    connect_changed[
                        password_dots = ui.password_dots.clone(),
                        password_prompt = ui.password_prompt.clone(),
                    ] => move |this| {
                        password_dots.queue_draw();
                        password_prompt.set_visible(this.text().is_empty());
                    },
                    connect_activate[
                        sender,
                        usernames_box = ui.usernames_box.clone(),
                        username_entry = ui.username_entry.clone(),
                        sessions_box = ui.sessions_box.clone(),
                        session_entry = ui.session_entry.clone(),
                    ] => move |this| {
                        sender.input(Self::Input::Login {
                            input: this.text().to_string(),
                            info: UserSessInfo::extract(
                                &usernames_box,
                                &username_entry,
                                &sessions_box,
                                &session_entry,
                            ),
                        })
                    },
                },

                #[template_child]
                visible_entry {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: model.updates.input_mode == InputMode::Visible,
                    #[track(
                        model.updates.changed(Updates::input_mode())
                        && model.updates.input_mode == InputMode::Visible
                    )]
                    grab_focus: (),
                    #[track(model.updates.changed(Updates::input()))]
                    set_text: &model.updates.input,
                    connect_activate[
                        sender,
                        usernames_box = ui.usernames_box.clone(),
                        username_entry = ui.username_entry.clone(),
                        sessions_box = ui.sessions_box.clone(),
                        session_entry = ui.session_entry.clone(),
                    ] => move |this| {
                        sender.input(Self::Input::Login {
                            input: this.text().to_string(),
                            info: UserSessInfo::extract(
                                &usernames_box,
                                &username_entry,
                                &sessions_box,
                                &session_entry,
                            ),
                        })
                    },
                },

                #[template_child]
                user_toggle {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_sensitive: !model.updates.is_input(),
                    connect_clicked => Self::Input::ToggleManualUser,
                },

                #[template_child]
                sess_toggle {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: !model.updates.is_input(),
                    connect_clicked => Self::Input::ToggleManualSess,
                },

                #[template_child]
                cancel_button {
                    connect_clicked => Self::Input::Cancel,
                },

                #[template_child]
                login_button {
                    #[track(
                        model.updates.changed(Updates::input_mode())
                        && !model.updates.is_input()
                    )]
                    grab_focus: (),
                    connect_clicked[
                        sender,
                        secret_entry = ui.secret_entry.clone(),
                        visible_entry = ui.visible_entry.clone(),
                        usernames_box = ui.usernames_box.clone(),
                        username_entry = ui.username_entry.clone(),
                        sessions_box = ui.sessions_box.clone(),
                        session_entry = ui.session_entry.clone(),
                    ] => move |_| {
                        sender.input(Self::Input::Login {
                            input: if secret_entry.is_visible() {
                                secret_entry.text().to_string()
                            } else if EntryExt::is_visible(&visible_entry) {
                                visible_entry.text().to_string()
                            } else {
                                String::new()
                            },
                            info: UserSessInfo::extract(
                                &usernames_box,
                                &username_entry,
                                &sessions_box,
                                &session_entry,
                            ),
                        })
                    },
                },

                #[template_child]
                end_controls {
                    #[track(model.updates.changed(Updates::input_mode()))]
                    set_visible: !model.updates.is_input(),
                },

                #[template_child]
                error_info {
                    #[track(
                        model.updates.changed(Updates::error())
                        || model.updates.changed(Updates::input_mode())
                    )]
                    set_revealed: model.updates.error.is_some() && !model.updates.is_input(),
                },

                #[template_child]
                error_label {
                    #[track(model.updates.changed(Updates::error()))]
                    set_label: model.updates.error.as_ref().unwrap_or(&"".to_string()),
                },

                #[template_child]
                reboot_button {
                    connect_clicked => Self::Input::Reboot,
                },

                #[template_child]
                poweroff_button {
                    connect_clicked => Self::Input::PowerOff,
                },
            }
        }
    }

    fn post_view() {
        if model.updates.changed(Updates::monitor()) {
            if let Some(monitor) = &model.updates.monitor {
                widgets.window.fullscreen_on_monitor(monitor);
                setup_settings(self, &widgets.window);
            }
        }
    }

    async fn init(
        input: Self::Init,
        root: Self::Root,
        sender: AsyncComponentSender<Self>,
    ) -> AsyncComponentParts<Self> {
        let mut model = Self::new(&input.config_path, input.demo).await;
        let widgets = view_output!();

        widgets.ui.error_info.set_visible(true);

        #[cfg(feature = "gtk4_8")]
        widgets
            .ui
            .background
            .set_content_fit(match model.config.get_background_fit() {
                BgFit::Fill => gtk4::ContentFit::Fill,
                BgFit::Contain => gtk4::ContentFit::Contain,
                BgFit::Cover => gtk4::ContentFit::Cover,
                BgFit::ScaleDown => gtk4::ContentFit::ScaleDown,
            });

        if let Err(err) = model.greetd_client.lock().await.cancel_session().await {
            warn!("Couldn't cancel greetd session: {err}");
        };

        model.choose_monitor(widgets.ui.display().name().as_str(), &sender);
        if let Some(monitor) = &model.updates.monitor {
            root.fullscreen_on_monitor(monitor);
        } else {
            root.fullscreen();
        }

        setup_settings(&model, &root);
        setup_users_sessions(&model, &widgets);

        if input.css_path.exists() {
            debug!("Loading custom CSS from file: {}", input.css_path.display());
            let provider = gtk::CssProvider::new();
            provider.load_from_path(input.css_path);
            gtk::style_context_add_provider_for_display(
                &widgets.ui.display(),
                &provider,
                gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
            );
        };

        model.clock.widget().add_css_class("cryoforge-clock");
        set_letter_spacing(model.clock.widget(), 3840);
        set_letter_spacing(&widgets.ui.date_label, 2175);
        set_letter_spacing(&widgets.ui.right_network_label, -96);
        set_letter_spacing(&widgets.ui.right_uptime_label, -96);
        set_letter_spacing(&widgets.ui.password_prompt, 768);

        let secret_entry = widgets.ui.secret_entry.clone();
        widgets
            .ui
            .password_dots
            .set_draw_func(move |_, context, _, _| {
                let count = secret_entry.text().chars().count().min(12);
                context.set_source_rgb(0xc4 as f64 / 255.0, 0x7f as f64 / 255.0, 0x8d as f64 / 255.0);
                let content_width = if count == 0 {
                    0.0
                } else {
                    16.0 + (count - 1) as f64 * 26.0
                };
                let first_x = (306.0 - content_width) / 2.0 + 8.0;

                for index in 0..count {
                    let x = first_x + index as f64 * 26.0;
                    context.arc(x, 10.0, 8.0, 0.0, std::f64::consts::TAU);
                    let _ = context.fill();
                }
            });

        refresh_status_labels(
            &widgets.ui.date_label,
            &widgets.ui.top_battery_label,
            &widgets.ui.top_network_label,
            &widgets.ui.right_network_label,
            &widgets.ui.right_power_label,
            &widgets.ui.right_uptime_label,
        );

        let date_label = widgets.ui.date_label.clone();
        let top_battery_label = widgets.ui.top_battery_label.clone();
        let top_network_label = widgets.ui.top_network_label.clone();
        let right_network_label = widgets.ui.right_network_label.clone();
        let right_power_label = widgets.ui.right_power_label.clone();
        let right_uptime_label = widgets.ui.right_uptime_label.clone();
        glib::timeout_add_seconds_local(60, move || {
            refresh_status_labels(
                &date_label,
                &top_battery_label,
                &top_network_label,
                &right_network_label,
                &right_power_label,
                &right_uptime_label,
            );
            glib::ControlFlow::Continue
        });

        let escape_controller = gtk::EventControllerKey::new();
        let escape_sender = sender.clone();
        escape_controller.connect_key_pressed(move |_, key, _, _| {
            if key == gdk::Key::Escape {
                escape_sender.input(InputMsg::Cancel);
                glib::Propagation::Stop
            } else {
                glib::Propagation::Proceed
            }
        });
        root.add_controller(escape_controller);

        root.set_default_widget(Some(&widgets.ui.login_button));

        if model.config.get_skip_selection() {
            sender.input(Self::Input::Login {
                input: String::new(),
                info: UserSessInfo::extract(
                    &widgets.ui.usernames_box,
                    &widgets.ui.username_entry,
                    &widgets.ui.sessions_box,
                    &widgets.ui.session_entry,
                ),
            });
        }

        AsyncComponentParts { model, widgets }
    }

    async fn update(
        &mut self,
        msg: Self::Input,
        sender: AsyncComponentSender<Self>,
        _root: &Self::Root,
    ) {
        debug!("Got input message: {msg:?}");

        self.updates.reset();

        match msg {
            Self::Input::Login { input, info } => {
                self.sess_info = Some(info);
                self.login_click_handler(&sender, input).await
            }
            Self::Input::Cancel => self.cancel_click_handler().await,
            Self::Input::UserChanged(info) => {
                self.sess_info = Some(info);
                self.user_change_handler();
            }
            Self::Input::ToggleManualUser => self
                .updates
                .set_manual_user_mode(!self.updates.manual_user_mode),
            Self::Input::ToggleManualSess => self
                .updates
                .set_manual_sess_mode(!self.updates.manual_sess_mode),
            Self::Input::Reboot => self.reboot_click_handler(&sender),
            Self::Input::PowerOff => self.poweroff_click_handler(&sender),
        }
    }

    async fn update_cmd(
        &mut self,
        msg: Self::CommandOutput,
        sender: AsyncComponentSender<Self>,
        _root: &Self::Root,
    ) {
        debug!("Got command message: {msg:?}");

        self.updates.reset();

        match msg {
            Self::CommandOutput::ClearErr => self.updates.set_error(None),
            Self::CommandOutput::HandleGreetdResponse(response) => {
                self.handle_greetd_response(&sender, response).await
            }
            Self::CommandOutput::RestartSession => self.create_session(&sender).await,
            Self::CommandOutput::MonitorRemoved(display_name) => {
                self.choose_monitor(display_name.as_str(), &sender)
            }
        };
    }
}
