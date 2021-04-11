using Adw;
using Gtk;

[GtkTemplate (ui = "/com/github/bleakgrey/tootle/ui/widgets/adaptive_button.ui")]
public class Tootle.Widgets.AdaptiveButton : Box {

	public string label { get; set; }
	public string icon_name { get; set; default = "image-loading-symbolic"; }

	public signal void clicked ();

	[GtkChild] unowned Button full;
	[GtkChild] unowned Button mini;
	[GtkChild] unowned Image image1;
	[GtkChild] unowned Image image2;

	construct {
		var butts = new Button[]{ full, mini };
		bind_property ("label", full, "label", BindingFlags.SYNC_CREATE);
		foreach (Button butt in butts) {
			bind_property ("tooltip_text", butt, "tooltip_text", BindingFlags.SYNC_CREATE);
			butt.clicked.connect (() => clicked ());
		}
		foreach (Image img in new Image[]{ image1, image2 }) {
			bind_property ("icon_name", img, "icon_name", BindingFlags.SYNC_CREATE);
		}
	}

}