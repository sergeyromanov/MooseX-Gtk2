use strictures 1;

# ABSTRACT: Connect Moose with Gtk2

package MooseX::Gtk2;

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use MooseX::Gtk2::Sugar::Signals ();
use MooseX::Gtk2::Init;

use syntax qw( simple/v2 );
use namespace::clean;

method init_meta ($class: %args) {
    Moose->init_meta(%args, base_class => 'Glib::Object');
    my $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $args{for_class},
        class_metaroles => {
            class => [qw(
                MooseX::Gtk2::MetaRole::Class::MakeGObject
                MooseX::Gtk2::MetaRole::Class::Destruction
                MooseX::Gtk2::MetaRole::Class::SignalHandling
            )],
            attribute => [qw(
                MooseX::Gtk2::MetaRole::Attribute::Register
                MooseX::Gtk2::MetaRole::Attribute::Access
            )],
        },
    );
    return $meta;
}

Moose::Exporter->setup_import_methods(
    also        => [qw( Moose MooseX::Gtk2::Sugar::Signals )],
    with_meta   => [qw( register )],
);

fun register ($meta) { $meta->make_gobject }

1;

__END__

=head1 SYNOPSIS

    package MyWindow;
    use MooseX::Gtk2;

    extends 'Gtk2::Window';

    has button => (
        is          => 'ro',
        isa         => 'Gtk2::Button',
        builder     => '_build_button',
    );

    sub _build_button { Gtk2::Button->new('Hello World') }

    sub BUILD {
        my ($self) = @_;
        $self->add($self->button);
    }

    register;

And later:

    use MyWindow;

    my $window = MyWindow->new(title => 'My App');
    $window->show_all;

    Gtk2->main;

=head1 DESCRIPTION

This extension allows you to use L<Moose> to declare L<Glib> classes that
are fit to be used as objects in L<Gtk2> applications. You cannot simply
subclass a C<Gtk2::Widget> and put it into a C<Gtk2::VBox>. The class has
to be registered with L<Glib> as an object class first. This is what
the call to L</register> accomplishes in the L</SYNOPSIS>.

Note that you don't have to load L<Gtk2> with the C<-init> switch or call
C<Gtk2-E<gt>init> yourself. This extension will make sure the package
L<MooseX::Gtk2::Init> is loaded which ensures initialization has taken
place.

While the behaviour of classes declared with this module is a bit different
than the use of their L<Gtk2> or L<Glib> parents, the original classes will
not be changed. Most of the differences are for maintainability's sake. I
tried to conform to L<Glib>/L<Gtk2> practices where appropriate.

=head2 Class Definitions

The class definitions look very similar to normal L<Moose> classes. First
you need to use C<MooseX::Gtk2> to initialize your metaclasses and import
the necessary declarative callbacks:

    package MyWidget;
    use MooseX::Gtk2;

Note that you don't have to C<use Moose>, since C<MooseX::Gtk2> uses
L<Moose::Exporter> and automatically sets up L<Moose> as well.

You will then usually define a class to extend with the L</extends>
keyword:

    extends 'Gtk2::Button';

If you don't specify a parent class, your new class will be based on
L<Glib::Object>. This can be useful if you want to build non-widget classes
which support L<Glib> signals.

Since L<Glib> only allows single inheritance, you will not be able to
inherit from more than one class at a time. Even if L<Glib> would support
this, it would probably be limited to avoid edge cases.

You can declare L</Properties> with L</has> and apply roles via L</with>
as usual. If you want your roles to provide signals, you'll have to use
L<MooseX::Gtk2::Role> as outlined in L</Role Definitions>.

Unlike normal Perl classes, the L<Glib> has to be told about your class
before it wants anything to do with it. This is why classes declared with
this module have to finalize themselves with a call to L</register>:

    register;

This function will throw an error when something goes wrong and return a
true value otherwise, so you can at least skip the C<1;> in these classes.
Calling this will effectively lock the class down, so make sure you do
any declarations and role applications before this.

After this, your class is ready to use.

=head2 Role Definitions

L<MooseX::Gtk2::Role>s are mostly just like L<Moose::Role>s:

    package MyRole;
    use MooseX::Gtk2::Role;

    requires qw( _handle_an_event );

    has a_property => (is => 'rw');

    signal an_event => (handler => '_handle_an_event');

    with qw( MyOtherRole );

    1;

Notice the C<1;> at the end? Since L<Glib> only cares about the structure
of the final classes, you don't have to register the roles you apply to
your classes during declaration.

An error will be thrown if you try to compose a L<MooseX::Gtk2::Role>
into something that doesn't know how to handle signals.

=head2 Object Construction

When you call C<new> on one of your declared classes, you always have
to pass in key/value pairs, no matter what your parent expects. All
constructors are overridden, so we don't have to maintain lots of special
cases. This means that while you can create a new C<Gtk2::Window> like this:

    Gtk2::Window->new('toplevel');

When you want to do the same with your own window class, you'd have to do:

    YourWindowClass->new(type => 'toplevel');

However, you can use C<BUILDARGS> (explained in L<Moose::Object/BUILDARGS>)
to modify the arguments the constructor accepts, just like regular L<Moose>
classes.

You can also use C<BUILD> and C<DEMOLISH> as usual.

=head2 Properties

What L<Moose> calls an I<attribute> is known to L<Glib> as a I<property>.
If you create an attribute on your subclass like the following:

    has some_attribute => (
        is          => 'rw',
        isa         => 'Str',
        required    => 1,
    );

Your attribute will automatically be prepared to be registered with L<Glib>
when you call L</register>.

Usually the C<is> option controls if you receive an accessor or just a
reader. In this case, however, it will have two different implications:

=over

=item * Generated Methods

You'll get a reader named C<get_some_attribute> and C<set_some_attribute>
instead of a reader or an accessor with the name of the attribute. This is
just the default, of course. It was chosen to maintain symmetry with L<Glib>
conventions.

=item * General Access

A C<Glib::Object> always also has a C<set> and a C<get> method that work
like the following:

    $object->set(foo => 23, bar => 17);
    my ($foo, $bar) = $object->get(qw( foo bar ));

Unless your parent class overrides these methods (C<Gtk2::TreeStore> is an
example that uses these methods to set row column values), they will be
overridden so your type constraints are respected (Note: This is only true
in Perl-space). The same is true for the C<get_property>/C<set_property>
aliases of C<get>/C<set>.

=back

It is also possible to extend L<Glib> properties inside your class:

    package MyWindow;
    use MooseX::Gtk2;

    extends 'Gtk2::Window';

    has '+title' => (isa => 'MyTypeConstraint');

    register;

Be careful, however, since full compatibility with all systems that access
these values can not be guaranteed at all.

In all cases, things like C<trigger>, C<isa> and lazy defaults will probably
not work correctly when triggered inside L<Glib>. This might change over
time, since it should be possible to emulate these behaviours via the
C<GET_PROPERTY>/C<SET_PROPERTY> facilities.

=head2 Signals

Signals are specific to L<Glib> and have no L<Moose> equivalent. You can
declare a new signal with the L</signal> keyword:

    signal new_signal => (@options);

See L</signal> for all available options. Signals and overrides can be
declared in classes as well as in roles. They can only be declared once
per class, and you cannot override a signal in the same class as you
declare it on. These restrictions include signals that are composed in via
roles.

=head1 EXPORTS

All of these are exported by default.

=head2 extends

    extends 'ParentClass';

Declares the parent class, which needs to be a subclass of C<Glib::Object>.
Multiple inheritance is not supported.

In case your parent class is a C<Glib::Object> that is not yet a
C<MooseX::Gtk2> extended class, your subclass will actually not directly
depend on the parent class, but on a membrane class which maps the L<Glib>
identity of the class into L<Moose> terms. This is the layer that makes
things such as attributes for existing L<Gtk2> properties possible.

=head2 has

    has attribute_name => (%options);

The possible options are the same as for normal L<Moose> attributes. You
can also extend existing attributes (even those provided by L<Glib> objects)
as normal with L<Moose>:

    has '+existing_attribute' => (%new_options);

Not all functionality of attributes might be avilable when trigger from
inside L<Glib>.

=head2 signal

    signal signal_name => (%options);

The above will simply declare a new signal. You can additionally override
an existing signal handler via:

    signal existing_signal => \&signal_handler_override;

The subroutine provided instead of a set of options will be used as new
signal handler. Overrides can only be done for signals provided above the
current class they are added to (including from roles). Signals and
overrides are also only settable once.

A signal defined like this can be called like the usual L<Glib> signals:

    my $return = $object->signal_emit(signal_name => $object, @args);

The available signal options are:

=over

=item C<arity>

Declares the number of arguments. Defaults to 0. The widget on which
the signal is emitted is always expected to be the first argument and is
not counted in the arity setting. Here is an example of a different arity:

    signal add => (
        arity   => 2,
        handler => '_handle_add',
    );

    sub _handle_add {
        my ($self, $num1, $num2) = @_;
        return $num1 + $num2;
    }

    $object->signal_emit(add => $object, 2, 3); # returns 5

=item C<runs>

Can be one of C<first>, C<last> or C<cleanup>. Defaults to C<last>. This
run type regulates when the handler will be run in the signal chain, and
what callback is able to return a value.

=item C<handler>

This should be either a method name or a code reference. The handler will
be called when the signal was emitted. When it will run depends on the
value passed to L</runs>.

=item C<restart>

If set to true, a signal will be restarted instead of running recursively
when it is fired while it is being handled.

=item C<collect>

The accumulator function. You probably don't want this unless you know that
you do.

=back

=head2 register

    register;

Requires no arguments. This must be called last in your class to register
it with L<Glib>. It will return a true value so you don't have to do that.

After this function is called, your class will also be immutable, and it
will stay that way. Once L<Glib> knows about your class, nothing can be
changed.

=head2 with

It's the same as usual.

=head1 CAVEATS

=head2 Object Reference Type

Only blessed hash references can be used. Trying to make it compatible
with something else would be a I<mess>.

=head2 Single Inheritance

L<Glib> only supports single inheritance. So we do the same.

=head2 BUILDALL and DEMOLISHALL

Don't hook into these, since they might not work as expected. Destruction
is handled completely by L<Glib>, since your object's lifetime might be
longer than that of the reference you have of it.

If you provide a C<DEMOLISH> method, calls to it will be emulated by
hooking into L<Glib>'s C<FINALIZE_INSTANCE>. The methods C<BUILD> and
C<BUILDARGS> should be available as usual.

=head2 Possible Attribute Value Bypasses

Things that are set by L<Glib> code outside of Perl or even just outside
C<MooseX::Gtk2>, might bypass specific functions of L<Moose> and set the
values directly. This needs to be emulated carefully, but there might
always be ways around the MOP.

=head2 Replacement of Getters and Setters

For attributes that are loaded from non-C<MooseX::Gtk2> classes, if we
can find C<set_*> and C<get_*> methods that have the right name, we'll
assume they are related to the attribute.

=head2 Interfaces

Currently not supported at all.

=head2 Dynamic Class Management

Since we have to register every class with L<Glib> or it won't be usable
as such, things like anonymous classes, or role-to-object application will
not work.

=head1 TODO

=over

=item * Provide C<requires_signals(@signal_names)> for roles.

=item * Support L<Glib::Object::Subclass/INTERFACES>.

=item * Allow to provide L<Glib> types other than C<Glib::Scalar>.

=item * Option to turn of implicit invocant signal parameter.

=item * More tests.

=back

=head1 SEE ALSO

=over

=item * L<Moose>

=item * L<Gtk2>

=item * L<Glib>

=item * L<http://developer.gnome.org/glib/>

=item * L<http://developer.gnome.org/gtk/>

=item * L<Glib::Object::Subclass>

=back

=cut
