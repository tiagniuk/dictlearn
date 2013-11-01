package Dict::Learn::Frame::AddWord 0.1;

use Wx qw[:everything];
use Wx::Event qw[:everything];

use Moose;
use MooseX::NonMoose;
extends 'Wx::Panel';

use Carp qw[croak confess];
use Data::Printer;
use LWP::UserAgent;
use List::Util qw[first];

use Dict::Learn::Combo::WordList;
use Dict::Learn::Dictionary;
use Dict::Learn::Translate;

use common::sense;

=item item_id

=cut

has item_id => (
    is      => 'rw',
    isa     => 'Int',
    clearer => 'clear_item_id',
);

=item enable

=cut

has enable => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub { 1 },
);

=item edit_origin

=cut

has edit_origin => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => 'has_edit_origin',
    clearer   => 'clear_edit_origin',
);

=item parent

=cut

has parent => (
    is  => 'ro',
    isa => 'Dict::Learn::Frame',
);

=item word_note

=cut

has word_note => (
    is      => 'ro',
    isa     => 'Wx::TextCtrl',
    default => sub {
        Wx::TextCtrl->new(shift, wxID_ANY, '', wxDefaultPosition,
            wxDefaultSize, wxTE_MULTILINE)
    },
);

=item word_src

=cut

has word_src => (
    is      => 'ro',
    isa     => 'Wx::TextCtrl',
    lazy    => 1,
    default => sub {
        Wx::TextCtrl->new(shift, wxID_ANY, '', wxDefaultPosition,
            wxDefaultSize, wxTE_MULTILINE)
    },
);

=item word2_src

=cut

has word2_src => (
    is         => 'ro',
    isa        => 'Wx::TextCtrl',
    lazy_build => 1,
);

sub _build_word2_src {
    my $self = shift;

    my $word2 = Wx::TextCtrl->new($self, wxID_ANY, '', wxDefaultPosition,
        wxDefaultSize);
    $word2->Enable(0);

    return $word2;
}

=item word3_src

=cut

has word3_src => (
    is         => 'ro',
    isa        => 'Wx::TextCtrl',
    lazy_build => 1,
);

sub _build_word3_src {
    my $self = shift;

    my $word3 = Wx::TextCtrl->new($self, wxID_ANY, '', wxDefaultPosition,
        wxDefaultSize);
    $word3->Enable(0);

    return $word3;
}

=item word_dst

=cut

has word_dst => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

=item cb_irregular

=cut

has cb_irregular => (
    is      => 'ro',
    isa     => 'Wx::CheckBox',
    lazy    => 1,
    default => sub {
        Wx::CheckBox->new(shift, wxID_ANY, 'Irregular verb',
            wxDefaultPosition, wxDefaultSize, wxCHK_2STATE,
            wxDefaultValidator)
    },
);

=item vbox_src

=cut

has vbox_src => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_vbox_src {
    my $self = shift;

    my $vbox_src = Wx::BoxSizer->new(wxVERTICAL);
    $vbox_src->Add($self->word_src,     2, wxGROW | wxEXPAND | wxBOTTOM, 5);
    $vbox_src->Add($self->cb_irregular, 1, wxALIGN_LEFT | wxBOTTOM,      5);
    $vbox_src->Add($self->word2_src,    1, wxGROW | wxBOTTOM,            5);
    $vbox_src->Add($self->word3_src,    1, wxGROW | wxBOTTOM,            5);

    return $vbox_src;
}

=item btn_additem

=cut

has btn_additem => (
    is      => 'ro',
    isa     => 'Wx::Button',
    lazy    => 1,
    default => sub {
        Wx::Button->new(shift, wxID_ANY, '+', wxDefaultPosition,
            wxDefaultSize)
    },
);

=item vbox_dst_item

=cut

has vbox_dst_item => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

=item hbox_add

=cut

has hbox_add => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_hbox_add {
    my $self = shift;

    my $hbox_add = Wx::BoxSizer->new(wxHORIZONTAL);
    $hbox_add->Add($self->btn_additem, wxALIGN_LEFT | wxRIGHT, 5);

    return $hbox_add;
}

=item vbox_dst

=cut

has vbox_dst => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_vbox_dst {
    my $self = shift;

    my $vbox_dst = Wx::BoxSizer->new(wxVERTICAL);
    $vbox_dst->Add($self->hbox_add, 0, wxALIGN_LEFT | wxRIGHT, 5);

    return $vbox_dst;
}

=item hbox_words

=cut

has hbox_words => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_hbox_words {
    my $self = shift;

    my $hbox_words = Wx::BoxSizer->new(wxHORIZONTAL);
    $hbox_words->Add($self->vbox_src, 2, wxALL | wxTOP,    5);
    $hbox_words->Add($self->vbox_dst, 4, wxALL | wxEXPAND, 5);

    return $hbox_words;
}

=item btn_add_word

=cut

has btn_add_word => (
    is      => 'ro',
    isa     => 'Wx::Button',
    lazy    => 1,
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Add', wxDefaultPosition,
            wxDefaultSize)
    },
);

=item btn_tran

=cut

has btn_tran => (
    is      => 'ro',
    isa     => 'Wx::Button',
    lazy    => 1,
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Translate', wxDefaultPosition,
            wxDefaultSize)
    },
);

=item btn_clear

=cut

has btn_clear => (
    is      => 'ro',
    isa     => 'Wx::Button',
    lazy    => 1,
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Clear', wxDefaultPosition,
            wxDefaultSize)
    },
);

=item btn_cancel

=cut

has btn_cancel => (
    is      => 'ro',
    isa     => 'Wx::Button',
    lazy    => 1,
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Cancel', wxDefaultPosition,
            wxDefaultSize)
    },
);

=item hbox_btn

=cut

has hbox_btn => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_hbox_btn {
    my $self = shift;

    my $hbox_btn = Wx::BoxSizer->new(wxHORIZONTAL);
    $hbox_btn->Add($self->btn_add_word, 0,
        wxBOTTOM | wxALIGN_LEFT | wxLEFT, 5);
    $hbox_btn->Add($self->btn_tran,   0, wxBOTTOM | wxALIGN_LEFT | wxLEFT, 5);
    $hbox_btn->Add($self->btn_clear,  0, wxBOTTOM | wxALIGN_LEFT | wxLEFT, 5);
    $hbox_btn->Add($self->btn_cancel, 0, wxBOTTOM | wxALIGN_LEFT | wxLEFT, 5);

    return $hbox_btn;
}

=item vbox

=cut

has vbox => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_vbox {
    my $self = shift;

    my $vbox = Wx::BoxSizer->new(wxVERTICAL);
    $vbox->Add($self->hbox_words, 3, wxALL | wxEXPAND | wxGROW, 0);
    $vbox->Add($self->word_note,  1, wxALL | wxEXPAND | wxGROW, 5);
    $vbox->Add($self->hbox_btn,   0, wxALL | wxGROW,            5);

    return $vbox;
}

sub keybind {
    my ($self, $event) = @_;

    given ($event->GetKeyCode()) {
        when ([WXK_ADD, WXK_NUMPAD_ADD]) {
            $self->add_dst_item();
        }
        when ([WXK_SUBTRACT, WXK_NUMPAD_SUBTRACT]) {
            if (my $last_word_obj
                = first { defined $_->{cbox} } reverse @{ $self->word_dst })
            {
                $self->del_dst_item($last_word_obj->{id});
            }
        }
    }
}

sub select_word {
    my ($self, $event) = @_;

    my $el = $self->add_dst_item($event->GetClientData(), 1);
    $el->{word}->SetValue($event->GetString);

    $self;
}

sub make_dst_item {
    my ($self, $word_id, $ro) = @_;

    my $vbox = Wx::BoxSizer->new(wxVERTICAL);
    my $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
    push @{ $self->vbox_dst_item } => $vbox;

    my $id = $#{ $self->vbox_dst_item };

    my %trans_panel = (
        word_id => $word_id,
        id      => $id,
        cbox    => Wx::ComboBox->new(
            $self, wxID_ANY,
            undef, wxDefaultPosition,
            [110, -1], [$self->import_partofspeech],
            wxCB_DROPDOWN | wxCB_READONLY, wxDefaultValidator
        ),
        popup => Dict::Learn::Combo::WordList->new(),
        word => Wx::ComboCtrl->new(
            $self,         wxID_ANY,
            '',            wxDefaultPosition,
            wxDefaultSize, wxCB_DROPDOWN,
            wxDefaultValidator
        ),
        note => Wx::TextCtrl->new($self, wxID_ANY, '', wxDefaultPosition,
            wxDefaultSize),
        btnm => Wx::Button->new(
            $self, wxID_ANY, '-', wxDefaultPosition, [40, -1]
        ),
        parent_vbox => $vbox,
        parent_hbox => $hbox,
    );

    $self->word_dst->[$id] = \%trans_panel;

    $trans_panel{word}
        ->SetPopupControl($trans_panel{popup});

    EVT_BUTTON(
        $self, $trans_panel{btnm},
        sub { $self->del_dst_item($id) }
    );

    my $part_of_speach_selection = 0;
    if ($id > 0 and my $prev_item = $self->word_dst->[$id - 1]) {
        return unless defined $prev_item->{cbox}
            and ref $prev_item->{cbox} eq 'Wx::ComboBox'
            and $prev_item->{cbox}->GetSelection >= 0;

        $part_of_speach_selection = $prev_item->{cbox}->GetSelection;
    }
    $trans_panel{cbox}->SetSelection($part_of_speach_selection);

    $hbox->Add($trans_panel{cbox}, 0, wxALL, 0);
    $hbox->Add($trans_panel{word}, 4, wxALL, 0);
    $hbox->Add($trans_panel{btnm}, 0, wxALL, 0);

    $vbox->Add($hbox, 0, wxEXPAND, 0);
    $vbox->Add($trans_panel{note}, 0, wxEXPAND, 0);

    if ($ro) {
        $trans_panel{word}->GetTextCtrl->SetEditable(0);
        $trans_panel{word}->GetPopupWindow->Disable;
        $trans_panel{edit}
            = Wx::Button->new($self, wxID_ANY, 'e', wxDefaultPosition,
            [40, -1]);

        EVT_BUTTON(
            $self, $trans_panel{edit},
            sub { $self->edit_word_as_new($id) }
        );
        $hbox->Add($trans_panel{edit}, 0, wxALL, 0);
    }

    return \%trans_panel;
}

sub query_words {
    my ($self, $id) = @_;

    my $cb = $self->word_dst->[$id]{word};
    my @words
        = $main::ioc->lookup('db')->schema->resultset('Word')
        ->select(Dict::Learn::Dictionary->curr->{language_tr_id}{language_id},
        $cb->GetValue());
    $cb->Clear;
    for (@words) {
        $cb->Append($_->{word});
    }
}

sub check_word {
    my ($self, $event) = @_;

    my $word;
    unless (
        defined(
            $word
                = $main::ioc->lookup('db')->schema->resultset('Word')->match(
                Dict::Learn::Dictionary->curr->{language_orig_id}
                    {language_id},
                $event->GetString
                )->first
        )
        )
    {
        $self->enable(1);
        $self->btn_add_word->SetLabel($self->item_id >= 0 ? 'Save' : 'Add');
        EVT_BUTTON($self, $self->btn_add_word, \&add);
    }
    else {
        if ($self->item_id >= 0) {
            return
                if $self->has_edit_origin
                and $self->edit_origin->{word} eq $event->GetString;
        }
        if ((my $word_id = $word->word_id) >= 0) {
            $self->enable(0);
            $self->btn_add_word->SetLabel(
                'Edit word "' . $self->word_src->GetValue . '"');
            EVT_BUTTON(
                $self,
                $self->btn_add_word,
                sub {
                    $self->enable(1);
                    $self->load_word(word_id => $word_id);
                    EVT_BUTTON($self, $self->btn_add_word, \&add);
                }
            );
        }
        else {
            $self->enable(1);
            $self->btn_add_word->SetLabel('Add');
            EVT_BUTTON($self, $self->btn_add_word, \&add);
        }
    }
    $self->enable_controls($self->enable);
}

sub add_dst_item {
    my ($self, $word_id, $ro) = @_;

    my $el = $self->make_dst_item($word_id, $ro);
    # $self->vbox_dst->Add( $el->{parent_vbox}, 1, wxALL|wxGROW, 0 );
    my @children = $self->vbox_dst->GetChildren;
    $self->vbox_dst->Insert($#children || 0,
        $el->{parent_vbox}, 1, wxALL | wxGROW, 0);
    $self->Layout();

    return $el;
}

sub del_dst_item {
    my ($self, $id) = @_;

    for (qw[ cbox word btnm btnp edit note ]) {
        next unless defined $self->word_dst->[$id]{$_};
        $self->word_dst->[$id]{$_}->Destroy();
        delete $self->word_dst->[$id]{$_};
    }
    $self->vbox_dst->Detach($self->vbox_dst_item->[$id])
        if defined $self->vbox_dst_item->[$id];
    $self->Layout();
    delete $self->vbox_dst_item->[$id];
    delete $self->word_dst->[$id]{parent_vbox};
    delete $self->word_dst->[$id]{parent_hbox};

    return $self;
}

sub edit_word_as_new {
    my ($self, $word_id) = @_;

    # set editable
    $self->word_dst->[$word_id]{word}->SetEditable(1);

    # remove example id
    $self->word_dst->[$word_id]{word_id} = undef;

    # remove edit button
    $self->word_dst->[$word_id]{edit}->Destroy();
    $self->word_dst->[$word_id]{parent_hbox}
        ->Remove($self->word_dst->[$word_id]{edit});
    delete $self->word_dst->[$word_id]{edit};

    return $self;
}

sub do_word_dst($$) {
    my ($self, $cb) = @_;

    for my $word_dst_item (grep {defined} @{$self->word_dst}) {
        $cb->($self, $word_dst_item);
    }
}

sub add {
    my $self = shift;

    my %params = (
        word => $self->word_src->GetValue(),
        note => $self->word_note->GetValue(),
        lang_id =>
            Dict::Learn::Dictionary->curr->{language_orig_id}{language_id},
        dictionary_id => Dict::Learn::Dictionary->curr_id,
    );
    if ($params{irregular} = $self->cb_irregular->IsChecked()) {
        $params{word2} = $self->word2_src->GetValue();
        $params{word3} = $self->word3_src->GetValue();
    }
    $self->do_word_dst(
        sub {
            my $trans_panel = pop;
            my %push_item = ( word_id => $trans_panel->{word_id} );
            if ($trans_panel->{word}) {
                $push_item{partofspeech}
                    = int($trans_panel->{cbox}->GetSelection());

                # `GetLabel` returns "" or value
                my $word_id = $trans_panel->{word}->GetLabel();
                $word_id = undef if $word_id eq '';
                if (defined $word_id and int $word_id >= 0) {
                    $push_item{word_id} = $word_id;
                    $push_item{word}    = 0;
                }
                else {
                    $push_item{word} = $trans_panel->{word}->GetValue();

                    # skip empty fields
                    next unless $push_item{word} =~ /^.+$/;
                }
                $push_item{note} = $trans_panel->{note}->GetValue();
                $push_item{lang_id}
                = Dict::Learn::Dictionary->curr->{language_tr_id}{language_id};
            }
            push @{$params{translate}} => \%push_item;
        }
    );
    if (defined $self->item_id
        and $self->item_id >= 0)
    {
        $params{word_id} = $self->item_id;
        $main::ioc->lookup('db')->schema->resultset('Word')
            ->update_one(%params);
    }
    else {
        $main::ioc->lookup('db')->schema->resultset('Word')->add_one(%params);
    }

    # Close the page after adding/editing the word
    $self->close_page();

    # TODO trigger an event informing that word list should be reloaded
    # $self->parent->p_search->lookup;

    return $self;
}

sub import_partofspeech {
    my $self = shift;

    map { $_->{name_orig} }
        $main::ioc->lookup('db')->schema->resultset('PartOfSpeech')->select();
}

sub clear_fields {
    my $self = shift;

    $self->clear_item_id;
    $self->clear_edit_origin;
    $self->enable(1);
    $self->enable_controls($self->enable);

    $self->word_src->Clear;

    # irregular words
    $self->word2_src->Clear;
    $self->word3_src->Clear;
    $self->enable_irregular(0);

    $self->do_word_dst(
        sub {
            my $word_dst_item = pop;
            return unless defined $word_dst_item->{word};
            $word_dst_item->{cbox}->SetSelection(0);
            $word_dst_item->{word}->SetText('');
            $word_dst_item->{note}->Clear;
        }
    );
    $self->word_note->Clear;
}

sub remove_all_dst {
    my $self = shift;

    for (@{$self->word_dst}) {
        $self->del_dst_item($_->{id});
        delete $self->word_dst->[$_->{id}];
    }
}

sub load_word {
    my ($self, %params) = @_;

    my $word   = $main::ioc->lookup('db')->schema->resultset('Word')
        ->select_one($params{word_id});
    my @translate;
    for my $rel_word (@{$word->{rel_words}}) {
        next unless $rel_word->{word2_id} or $rel_word->{word2_id}{word_id};
        push @translate => {
            word_id      => $rel_word->{word2_id}{word_id},
            word         => $rel_word->{word2_id}{word},
            partofspeech => $rel_word->{partofspeech_id},
            note         => $rel_word->{note},
        };
    }
    $self->fill_fields(
        word_id      => $word->{word_id},
        word         => $word->{word},
        word2        => $word->{word2},
        word3        => $word->{word3},
        irregular    => $word->{irregular},
        partofspeech => $word->{partofspeech_id},
        note         => $word->{note},
        translate    => \@translate,
    );
    $self->btn_add_word->SetLabel('Save');
}

sub fill_fields {
    my ($self, %params) = @_;

    $self->clear_fields;
    $self->edit_origin(\%params);
    $self->item_id($params{word_id});
    $self->remove_all_dst;
    $self->word_src->SetValue($params{word});
    $self->enable_irregular($params{irregular});

    if ($params{irregular}) {
        $self->word2_src->SetValue($params{word2}) if $params{word2};
        $self->word3_src->SetValue($params{word3}) if $params{word3};
    }
    for my $word_tr (@{$params{translate}}) {
        my $el = $self->add_dst_item($word_tr->{word_id} => 1);
        $el->{word}->SetValue($word_tr->{word});
        $el->{word}->SetLabel($word_tr->{word_id});
        $el->{note}->SetValue($word_tr->{note});
        $el->{cbox}->SetSelection($word_tr->{partofspeech});
    }
    $self->word_note->SetValue($params{note});
}

sub dst_count { scalar @{$_[0]->word_dst} }

sub get_partofspeech_index {
    my ($self, $name) = @_;

    for ($main::ioc->lookup('db')->schema->resultset('PartOfSpeech')
        ->select(name => $name))
    {
        return $_->{partofspeech_id};
    }
}

sub _add_translation_item {
    my ($self, $word, $partofspeech) = @_;

    my $trans_item = $self->add_dst_item;
    $trans_item->{cbox}->SetSelection(
        $self->get_partofspeech_index(
            $partofspeech)
    );
    $trans_item->{word}->SetValue($word->{word});
    my $note = '';
    $note = "( $word->{category} )"
        if $word->{category};
    $note .= ($note ? ' ' : '') . $word->{note}
        if $word->{note};
    $trans_item->{note}->SetValue($note) if $note;
}

sub translate_word {
    my $self = shift;

    my $res  = $self->parent->tran->do(
        'en' => 'uk',
        $self->word_src->GetValue()
    );
    p($res);
    my $limit = $self->dst_count;
    if (keys %$res >= 1) {
        for my $meaning_group (keys %$res) {
            for my $partofspeech (keys %$res->{$meaning_group}) {
                next
                    if $partofspeech eq '_'
                    and ref $res->{$meaning_group}{$partofspeech} eq '';
                for my $words (@{$res->{$meaning_group}{$partofspeech}}) {
                    given (ref $words) {
                        when ('ARRAY') {
                            for my $word (@$words) {
                                $self->_add_translation_item(
                                    $word, $partofspeech);
                            }
                        }
                        when ('HASH') {
                            $self->_add_translation_item(
                                $words, $partofspeech);
                        }
                    }
                }
            }
        }
    }
}

sub enable_irregular {
    my ($self, $is_checked) = @_;

    $self->cb_irregular->SetValue($is_checked);
    $self->word2_src->Enable($is_checked);
    $self->word3_src->Enable($is_checked);
}

sub toggle_irregular {
    my ($self, $event) = @_;

    $self->enable_irregular($event->IsChecked);
}

sub enable_controls($$) {
    my ($self, $en) = @_;

    $self->btn_additem->Enable($en);

    # $self->btn_add_word->Enable($en);
    $self->btn_clear->Enable($en);
    $self->word_note->Enable($en);
    $self->btn_tran->Enable($en);
    $self->do_word_dst(
        sub {
            my $item = pop;
            return unless defined $item->{word};
            $item->{word}->Enable($en);
            $item->{cbox}->Enable($en);
            $item->{btnm}->Enable($en);
            $item->{edit}->Enable($en) if $item->{edit};
        }
    );
}

sub close_page {
    my $self = shift;

    $self->clear_fields();
    $self->remove_all_dst();

    $self->parent->notebook->DeletePage(
        $self->parent->notebook->GetSelection()
    );
}

sub FOREIGNBUILDARGS {
    my ($class, $parent, @args) = @_;
    return @args;
}

sub BUILDARGS {
    my ($class, $parent) = @_;
    return { parent => $parent };
}

sub BUILD {
    my ($self, @args) = @_;

    ### main layout  
    $self->SetSizer($self->vbox);
    $self->Layout();
    $self->vbox->Fit($self);

    # events
    EVT_BUTTON($self, $self->btn_add_word, \&add);
    EVT_BUTTON($self, $self->btn_additem,  sub { $self->add_dst_item });
    EVT_BUTTON($self, $self->btn_clear,    \&clear_fields);
    EVT_BUTTON($self, $self->btn_tran,     \&translate_word);
    EVT_BUTTON($self, $self->btn_cancel,   \&close_page);
    EVT_CHECKBOX($self, $self->cb_irregular, \&toggle_irregular);
    EVT_TEXT($self, $self->word_src, \&check_word);

    EVT_KEY_UP($self, sub { $self->keybind($_[1]) });
    $self;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
