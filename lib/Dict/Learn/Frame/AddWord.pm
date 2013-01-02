package Dict::Learn::Frame::AddWord 0.1;

use Wx qw[:everything];
use Wx::Grid;
use Wx::Event qw[:everything];

use base 'Wx::Panel';

use LWP::UserAgent;

# use lib qw[ ];

use Dict::Learn::Translate;
use Dict::Learn::Combo::WordList;
use Dict::Learn::Dictionary;

use common::sense;
use Carp qw[croak confess];
use Data::Printer;

use Class::XSAccessor
  accessors => [ qw| parent
                     word_note wordclass
                     word_src word2_src word3_src word_dst
                     vbox hbox_words vbox_dst hbox_dst_item
                     vbox_src cb_irregular

                     hbox_btn

                     item_id

                     hbox_add btn_additem

                     btn_add_word btn_clear btn_tran btn_cancel
                     tran
                     enable
                     edit_origin
                   | ];

sub new {
  my $class  = shift;
  my $self   = $class->SUPER::new( splice @_ => 1 );
  $self->tran( Dict::Learn::Translate->new() );
  $self->parent( shift );

  ### src
  $self->word_src(   Wx::TextCtrl->new( $self, -1, '', [-1,-1], [-1,-1] ));
  $self->word2_src(  Wx::TextCtrl->new( $self, -1, '', [-1,-1], [-1,-1] ));
  $self->word3_src(  Wx::TextCtrl->new( $self, -1, '', [-1,-1], [-1,-1] ));
  $self->word2_src->Enable(0);
  $self->word3_src->Enable(0);
  $self->cb_irregular( Wx::CheckBox->new( $self, wxID_ANY, 'Irregular verb', wxDefaultPosition, wxDefaultSize, wxCHK_2STATE, wxDefaultValidator ) );
  $self->word_note( Wx::TextCtrl->new( $self, -1, '', [-1,-1], [-1,-1] ));
  # layout
  $self->vbox_src( Wx::BoxSizer->new( wxVERTICAL ));
  $self->vbox_src->Add($self->word_src, 0, wxGROW|wxBOTTOM, 5);
  $self->vbox_src->Add($self->cb_irregular, 0, wxALIGN_LEFT|wxBOTTOM, 5);
  $self->vbox_src->Add($self->word2_src, 0, wxGROW|wxBOTTOM, 5);
  $self->vbox_src->Add($self->word3_src, 0, wxGROW|wxBOTTOM, 5);

  ### dst
  $self->word_dst([]);
  $self->btn_additem( Wx::Button->new( $self, -1, '+', [-1, -1] ));
  # layout
  $self->hbox_dst_item([]);
  $self->vbox_dst( Wx::BoxSizer->new( wxVERTICAL ));
  $self->hbox_add( Wx::BoxSizer->new( wxHORIZONTAL ));
  $self->hbox_add->Add($self->btn_additem, wxALIGN_LEFT|wxRIGHT, 5);
  $self->vbox_dst->Add($self->hbox_add, 0, wxALIGN_LEFT|wxRIGHT, 5);

  ### hbox_words layout
  $self->hbox_words( Wx::BoxSizer->new( wxHORIZONTAL ) );
  $self->hbox_words->Add( $self->vbox_src, 2, wxALL|wxTOP,    5 );
  $self->hbox_words->Add( $self->vbox_dst, 4, wxALL|wxEXPAND, 5 );

  ### btn
  $self->btn_add_word( Wx::Button->new( $self, -1, 'Add',       [-1, -1] ));
  $self->btn_tran(     Wx::Button->new( $self, -1, 'Translate', [-1, -1] ));
  $self->btn_clear(    Wx::Button->new( $self, -1, 'Clear',     [-1, -1] ));
  $self->btn_cancel(   Wx::Button->new( $self, -1, 'Cancel',    [-1, -1] ));
  # layout
  $self->hbox_btn( Wx::BoxSizer->new( wxHORIZONTAL ) );
  $self->hbox_btn->Add( $self->btn_add_word, 0, wxBOTTOM|wxALIGN_LEFT|wxLEFT, 5 );
  $self->hbox_btn->Add( $self->btn_tran,     0, wxBOTTOM|wxALIGN_LEFT|wxLEFT, 5 );
  $self->hbox_btn->Add( $self->btn_clear,    0, wxBOTTOM|wxALIGN_LEFT|wxLEFT, 5 );
  $self->hbox_btn->Add( $self->btn_cancel,   0, wxBOTTOM|wxALIGN_LEFT|wxLEFT, 5 );

  ### main layout
  $self->vbox( Wx::BoxSizer->new( wxVERTICAL ) );
  $self->vbox->Add( $self->hbox_words, 0, wxALL|wxGROW, 0 );
  $self->vbox->Add( $self->word_note,  0, wxALL|wxGROW, 5 );
  $self->vbox->Add( $self->hbox_btn,   0, wxALL|wxGROW, 5 );
  $self->SetSizer( $self->vbox );
  $self->Layout();
  $self->vbox->Fit( $self );

  # mode: undef - add, other - edit
  $self->item_id(undef);
  $self->enable(1);

  # events
  EVT_BUTTON(   $self, $self->btn_add_word, \&add                       );
  EVT_BUTTON(   $self, $self->btn_additem,  sub { $self->add_dst_item } );
  EVT_BUTTON(   $self, $self->btn_clear,    \&clear_fields              );
  EVT_BUTTON(   $self, $self->btn_tran,     \&translate_word            );
  EVT_BUTTON(   $self, $self->btn_cancel,   \&cancel                    );
  EVT_CHECKBOX( $self, $self->cb_irregular, \&toggle_irregular          );
  EVT_TEXT(     $self, $self->word_src,     \&check_word                );
  $self
}

sub select_word {
  my ($self, $event) = @_;
  my $el = $self->add_dst_item( $event->GetClientData(), 1 );
  $el->{word}->SetValue( $event->GetString );
  $self
}

sub make_dst_item {
  my ($self, $word_id, $ro) = @_;
  push @{ $self->hbox_dst_item } => Wx::BoxSizer->new( wxHORIZONTAL );
  my $id = $#{ $self->hbox_dst_item };
  $self->word_dst->[$id] = {
    word_id => $word_id,
    id      => $id,
    cbox    => Wx::ComboBox->new( $self, wxID_ANY, undef, wxDefaultPosition, wxDefaultSize, [ $self->import_wordclass ], wxCB_DROPDOWN|wxCB_READONLY, wxDefaultValidator  ),
    popup   => Dict::Learn::Combo::WordList->new(),
    # word    => Wx::TextCtrl->new( $self, -1, '', [-1,-1], [-1,-1] ),
    # word    => Wx::ComboBox->new( $self, wxID_ANY, undef, wxDefaultPosition, wxDefaultSize, [], wxCB_DROPDOWN, wxDefaultValidator  ),
    word    => Wx::ComboCtrl->new( $self, wxID_ANY, "", wxDefaultPosition, wxDefaultSize, wxCB_DROPDOWN, wxDefaultValidator ),
    # btnp    => Wx::Button->new( $self, -1, '+', [-1, -1] ),
    btnm    => Wx::Button->new( $self, -1, '-', [-1, -1] ),
    parent_hbox => $self->hbox_dst_item->[$id]
  };
  $self->word_dst->[$id]{word}->SetPopupControl( $self->word_dst->[$id]{popup} );
  # $self->word_dst->[$id]{word}->SetTextCtrlStyle( wxTE_MULTILINE );
  # EVT_BUTTON( $self, $self->word_dst->[$id]{btnp}, sub { $self->add_dst_item(); } );
  EVT_BUTTON( $self, $self->word_dst->[$id]{btnm}, sub { $self->del_dst_item($id); } );
  # EVT_TEXT(   $self, $self->word_dst->[$id]{word}, sub { $self->query_words($id); } );
  $self->word_dst->[$id]{cbox}->SetSelection(0);
  $self->hbox_dst_item->[$id]->Add($self->word_dst->[$id]{cbox}, 2, wxALL, 0);
  $self->hbox_dst_item->[$id]->Add($self->word_dst->[$id]{word}, 4, wxALL, 0);
  $self->hbox_dst_item->[$id]->Add($self->word_dst->[$id]{btnm}, 1, wxALL, 0);

  if ($ro) {
    # $self->word_dst->[$id]{word}->SetEditable(0);
    $self->word_dst->[$id]{word}->GetTextCtrl->SetEditable(0);
    $self->word_dst->[$id]{word}->GetPopupWindow->Disable;
    $self->word_dst->[$id]{edit} = Wx::Button->new( $self, -1, 'e', [-1, -1] );
    EVT_BUTTON( $self, $self->word_dst->[$id]{edit}, sub { $self->edit_word_as_new($id) } );
    $self->hbox_dst_item->[$id]->Add($self->word_dst->[$id]{edit}, 1, wxALL, 0);
  }

  $self->word_dst->[$id]
}

sub query_words {
  my ($self, $id) = @_;
  my $cb = $self->word_dst->[$id]{word};
  my @words = $main::ioc->lookup('db')->schema->resultset('Word')->select(
    Dict::Learn::Dictionary->curr->{language_tr_id}{language_id},
    $cb->GetValue(),
  );
  $cb->Clear;
  for (@words) {
    $cb->Append($_->{word});
  }
}

sub check_word {
  my ($self, $event) = @_;
  my $word;
  unless (defined($word = $main::ioc->lookup('db')->schema->resultset('Word')->match(
    Dict::Learn::Dictionary->curr->{language_orig_id}{language_id},
    $event->GetString )->first))
  {
    $self->enable(1);
    $self->btn_add_word->SetLabel($self->item_id >= 0 ? 'Save' : 'Add');
    EVT_BUTTON( $self, $self->btn_add_word, \&add );
  }
  else {
    if ($self->item_id >= 0 ) {
      return if $self->edit_origin and $self->edit_origin->{word} eq $event->GetString;
    }
    if ( (my $word_id = $word->word_id) >= 0)
    {
      $self->enable(0);
      $self->btn_add_word->SetLabel('Edit word "'.$self->word_src->GetValue.'"');
      EVT_BUTTON( $self, $self->btn_add_word, sub {
        $self->enable(1);
        $self->load_word(word_id => $word_id);
        EVT_BUTTON( $self, $self->btn_add_word, \&add );
      } );
    } else {
      $self->enable(1);
      $self->btn_add_word->SetLabel('Add');
      EVT_BUTTON( $self, $self->btn_add_word, \&add );
    }
  }
  $self->enable_controls($self->enable);
}

sub add_dst_item {
  my ($self, $word_id, $ro) = @_;
  my $el = $self->make_dst_item( $word_id, $ro );
  # $self->vbox_dst->Add( $el->{parent_hbox}, 1, wxALL|wxGROW, 0 );
  my @children = $self->vbox_dst->GetChildren;
  $self->vbox_dst->Insert( $#children || 0, $el->{parent_hbox}, 1, wxALL|wxGROW, 0 );
  $self->Layout();
  $el
}

sub del_dst_item {
  my $self = shift;
  my $id = shift;
  for (qw[ cbox word btnm btnp edit ]) {
    next unless defined $self->word_dst->[$id]{$_};
    $self->word_dst->[$id]{$_}->Destroy();
    delete $self->word_dst->[$id]{$_};
  }
  $self->vbox_dst->Detach($self->hbox_dst_item->[$id])
    if defined $self->hbox_dst_item->[$id];
  $self->Layout();
  delete $self->hbox_dst_item->[$id];
  delete $self->word_dst->[$id]{parent_hbox};
  $self
}

sub edit_word_as_new {
  my ($self, $word_id) = @_;
  # set editable
  $self->word_dst->[$word_id]{word}->SetEditable(1);
  # remove example id
  $self->word_dst->[$word_id]{word_id} = undef;
  # remove edit button
  $self->word_dst->[$word_id]{edit}->Destroy();
  $self->word_dst->[$word_id]{parent_hbox}->Remove(
    $self->word_dst->[$word_id]{edit}
  );
  delete $self->word_dst->[$word_id]{edit};
  $self
}

sub do_word_dst($$) {
  my ($self, $cb) = @_;
  for my $word_dst_item ( grep { defined } @{ $self->word_dst } ) {
    $cb->($self, $word_dst_item);
  }
}

sub add {
  my $self = shift;

  my %params = (
    word    => $self->word_src->GetValue(),
    note    => $self->word_note->GetValue(),
    lang_id => Dict::Learn::Dictionary->curr->{language_orig_id}{language_id},
    dictionary_id => Dict::Learn::Dictionary->curr_id,
  );
  if ($params{irregular} = $self->cb_irregular->IsChecked()) {
    $params{word2} = $self->word2_src->GetValue();
    $params{word3} = $self->word3_src->GetValue();
  }
  $self->do_word_dst(sub {
    my $word_dst_item = pop;
    my $push_item = { word_id => $word_dst_item->{word_id} };
    if ($word_dst_item->{word}) {
      $push_item->{wordclass} = int($word_dst_item->{cbox}->GetSelection());
      # `GetLabel` returns "" or value
      my $word_id = $word_dst_item->{word}->GetLabel();
      $word_id = undef if $word_id eq "";
      if (defined $word_id and int $word_id >= 0) {
        $push_item->{word_id} = $word_id;
        $push_item->{word} = 0;
      } else {
        $push_item->{word} = $word_dst_item->{word}->GetValue();
        # skip empty fields
        next unless $push_item->{word} =~ /^.+$/;
      }
      $push_item->{lang_id} = Dict::Learn::Dictionary->curr->{language_tr_id}{language_id};
    }
    push @{$params{translate}} => $push_item;
  });
  if (defined $self->item_id and
              $self->item_id >= 0)
  {
    $params{word_id} = $self->item_id ;
    $main::ioc->lookup('db')->schema->resultset('Word')->update_one(%params);
  } else {
    $main::ioc->lookup('db')->schema->resultset('Word')->add_one(%params);
  }
  $self->clear_fields;
  $self->remove_all_dst;
  $self->parent->notebook->SetPageText(1 => "Word");
  $self->btn_add_word->SetLabel('Add');

  # reload linked words
  $self->parent->p_addexample->load_words;

  $self
}

sub import_wordclass {
  my $self = shift;
  map { $_->{name_orig} } $main::ioc->lookup('db')->schema->resultset('Wordclass')->select()
}

sub clear_fields {
  my $self = shift;

  $self->item_id(undef);
  $self->edit_origin(undef);
  $self->enable(1);
  $self->enable_controls($self->enable);

  $self->word_src->Clear;
  # irregular words
  $self->word2_src->Clear;
  $self->word3_src->Clear;
  $self->enable_irregular(0);

  $self->do_word_dst(sub {
    my $word_dst_item = pop;
    return unless defined $word_dst_item->{word};
    $word_dst_item->{cbox}->SetSelection(0);
    $word_dst_item->{word}->SetText("");
  });
  $self->word_note->Clear;
}

sub remove_all_dst {
  my $self = shift;
  for ( @{ $self->word_dst } ) {
    $self->del_dst_item($_->{id});
    delete $self->word_dst->[$_->{id}];
  }
}

sub load_word {
  my $self   = shift;
  my %params = @_;
  my $word   = $main::ioc->lookup('db')->schema->resultset('Word')->select_one( $params{word_id} );
  my @translate;
  for my $rel_word (@{ $word->{rel_words} }) {
    next unless $rel_word->{word2_id} or $rel_word->{word2_id}{word_id};
    push @translate => {
      word_id   => $rel_word->{word2_id}{word_id},
      word      => $rel_word->{word2_id}{word},
      wordclass => $rel_word->{wordclass_id},
      note      => $rel_word->{note},
    };
  }
  $self->fill_fields(
    word_id   => $word->{word_id},
    word      => $word->{word},
    word2     => $word->{word2},
    word3     => $word->{word3},
    irregular => $word->{irregular},
    wordclass => $word->{wordclass_id},
    note      => $word->{note},
    translate => \@translate,
  );
  $self->btn_add_word->SetLabel('Save');
}

sub fill_fields {
  my $self   = shift;
  my %params = @_;
  $self->clear_fields;
  $self->edit_origin(\%params);
  $self->item_id( $params{word_id} );
  $self->remove_all_dst;
  $self->word_src->SetValue($params{word});
  $self->enable_irregular($params{irregular});
  if ($params{irregular}) {
    $self->word2_src->SetValue($params{word2}) if $params{word2};
    $self->word3_src->SetValue($params{word3}) if $params{word3};
  }
  for my $word_tr ( @{ $params{translate} } ) {
    my $el = $self->add_dst_item($word_tr->{word_id} => 1);
    $el->{word}->SetValue($word_tr->{word});
    $el->{word}->SetLabel($word_tr->{word_id});
    $el->{cbox}->SetSelection($word_tr->{wordclass});
  }
  $self->word_note->SetValue($params{note});

  $self->parent->notebook->SetPageText(
    1 => "Edit item id#".$self->item_id);
}

sub dst_count { scalar @{ $_[0]->word_dst } }

sub get_partofspeach_index {
  my $self = shift;
  my $name = shift;
  for ($main::ioc->lookup('db')->schema->resultset('Wordclass')->select( name => $name ))
    { return $_->{wordclass_id} }
}

sub translate_word {
  my $self = shift;
  my $res = $self->tran->using('Google')->do(
    'en' => 'uk',
    $self->word_src->GetValue()
  );
  p($res);
  my $limit = $self->dst_count;
  if (keys %$res > 1) {
    my $i = 0;
    for my $partofspeach ( keys %$res ) {
      next if $partofspeach eq '_';
      $self->add_dst_item if $i >= $limit;
      $self->word_dst->[$i]{cbox}->SetSelection(
        $self->get_partofspeach_index($partofspeach)
      );
      $self->word_dst->[$i]{word}->SetValue( join ' | ' =>
        map { ref $_ eq 'ARRAY' ? $_->[0] : $_ } @{$res->{$partofspeach}}
      );
      $i++;
    }
  }
  else {
    $self->word_dst->[0]{word}->SetValue( $res->{_} );
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
  $self->enable_irregular($event->IsChecked)
}

sub enable_controls($$) {
  my ($self, $en) = @_;
  $self->btn_additem->Enable($en);
  # $self->btn_add_word->Enable($en);
  $self->btn_clear->Enable($en);
  $self->word_note->Enable($en);
  $self->btn_tran->Enable($en);
  $self->do_word_dst(sub {
    my $item = pop;
    $item->{word}->Enable($en);
    $item->{cbox}->Enable($en);
    $item->{btnm}->Enable($en);
    $item->{edit}->Enable($en) if $item->{edit};
  });
}

sub cancel {
  my $self = shift;
  $self->clear_fields();
  $self->remove_all_dst();
  $self->parent->notebook->SetPageText(1 => "Word");
}

1;
