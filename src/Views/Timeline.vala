using Gtk;
using Gdk;

public class Tootle.Views.Timeline : IAccountHolder, IStreamListener, Views.ContentBase {

	public string url { get; construct set; }
	public bool is_public { get; construct set; default = false; }
	public Type accepts { get; set; default = typeof (API.Status); }

	protected InstanceAccount? account { get; set; default = null; }
	protected ulong on_status_added_sigig;

	public bool is_last_page { get; set; default = false; }
	public string? page_next { get; set; }
	public string? page_prev { get; set; }
	public string? stream = null;

	construct {
		app.refresh.connect (on_refresh);
		status_button.clicked.connect (on_refresh);
		account_listener_init ();

		content.bind_model (model, create_model_widget);

		on_status_added_sigig = on_status_added.connect (add_status);
		on_status_removed.connect (remove_status);
	}
	~Timeline () {
		streams.unsubscribe (stream, this);
	}

	public virtual Widget create_model_widget (Object obj) {
		var w = obj as Widgetizable;
		return w.to_widget ();
	}

	public virtual bool is_status_owned (API.Status status) {
		return status.is_owned ();
	}

	public override void clear () {
		this.page_prev = null;
		this.page_next = null;
		this.is_last_page = false;
		this.needs_attention = false;
		base.clear ();
	}

	public void get_pages (string? header) {
		page_next = page_prev = null;
		if (header == null)
			return;

		var pages = header.split (",");
		foreach (var page in pages) {
			var sanitized = page
				.replace ("<","")
				.replace (">", "")
				.split (";")[0];

			if ("rel=\"prev\"" in page)
				page_prev = sanitized;
			else
				page_next = sanitized;
		}

		is_last_page = page_prev != null & page_next == null;
	}

	public virtual string get_req_url () {
		if (page_next != null)
			return page_next;
		return url;
	}

	public virtual Request append_params (Request req) {
		if (page_next == null)
			return req.with_param ("limit", @"$(settings.timeline_page_size)");
		else
			return req;
	}

	public virtual void on_request_finish () {}

	public virtual bool request () {
		var req = append_params (new Request.GET (get_req_url ()))
		.with_account (account)
		.with_ctx (this)
		.then ((sess, msg) => {
			Network.parse_array (msg, node => {
				try {
					var e = Entity.from_json (accepts, node);
					model.append (e);
				}
				catch (Error e) {
					warning (@"Timeline item parse error: $(e.message)");
				}
			});

			get_pages (msg.response_headers.get_one ("Link"));
			on_content_changed ();
			on_request_finish ();
		})
		.on_error (on_error);
		req.exec ();

		return GLib.Source.REMOVE;
	}

	public virtual void on_refresh () {
		scrolled.vadjustment.value = 0;
		status_button.sensitive = false;
		clear ();
		status_message = STATUS_LOADING;
		GLib.Idle.add (request);
	}

	public virtual string? get_stream_url () {
		return null;
	}

	public virtual void on_account_changed (InstanceAccount? acc) {
		account = acc;
		reconnect_stream ();
		on_refresh ();
	}

	public void reconnect_stream () {
		streams.unsubscribe (stream, this);
		streams.subscribe (get_stream_url (), this, out stream);
	}

	protected override void on_bottom_reached () {
		if (is_last_page) {
			info ("Last page reached");
			return;
		}
		request ();
	}

	protected virtual void add_status (API.Status status) {
		var allow_update = true;
		if (is_public)
			allow_update = settings.public_live_updates;

		if (settings.live_updates && allow_update)
			model.insert (-1, status);
	}

	protected virtual void remove_status (string id) {
		if (settings.live_updates) {
			// content_list.get_children ().@foreach (w => {
			// 	var sw = w as Widgets.Status;
			// 	if (sw != null && sw.status.id == id)
			// 		sw.destroy ();
			// });
		}
	}

}
