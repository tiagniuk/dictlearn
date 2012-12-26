package Dict::Learn::Frame 0.1;

use Wx qw[:everything];
use Wx::Grid;
use Wx::Event qw[:everything];

use base 'Wx::Frame';

use Data::Printer;

use File::Basename 'dirname';
use lib dirname(__FILE__).'/../lib/';

use Dict::Learn::Db;
use Dict::Learn::Frame::AddWord;
use Dict::Learn::Frame::AddExample;
use Dict::Learn::Frame::GridWords;
use Dict::Learn::Frame::GridExamples;
use Dict::Learn::Frame::SearchWords;
use Dict::Learn::Frame::IrregularVerbsTest;

use common::sense;

use Class::XSAccessor
  accessors => [ qw| vbox menu_bar menu_dicts menu_db status_bar notebook
                     p_additem p_addword p_addexample p_gridwords p_search
                     p_gridexamples
                     pt_irrverbs
               | ];

use constant DICT_OFFSET => 100;

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new( @_ );

  $self->SetIcon( Wx::GetWxPerlIcon() );
  $self->vbox( Wx::BoxSizer->new( wxVERTICAL ) );
  $self->notebook( Wx::Notebook->new( $self, wxID_ANY, wxDefaultPosition, wxDefaultSize, 0 ) );

  # main menu
  my $menu_id = 0;
  $self->menu_bar( Wx::MenuBar->new(0) );
  $self->SetMenuBar( $self->menu_bar );
  $self->menu_dicts( Wx::Menu->new );
  $self->menu_bar->Append( $self->menu_dicts, 'Dictionaries' );
  $self->init_menu_dicts( $self->menu_dicts );
  $self->menu_db( Wx::Menu->new );
  $self->menu_bar->Append( $self->menu_db, 'DB' );
  $self->menu_db->Append(++$menu_id, 'Export');
  EVT_MENU($self, $menu_id, \&export);
  $self->menu_db->Append(++$menu_id, 'Import');
  EVT_MENU($self, $menu_id, \&import);

  # panel search

  $self->p_search( Dict::Learn::Frame::SearchWords->new( $self, $self->notebook, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ));
  $self->notebook->AddPage( $self->p_search, "Search", 1 );

  # panel addword

  $self->p_addword( Dict::Learn::Frame::AddWord->new( $self, $self->notebook, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ));

  $self->notebook->AddPage( $self->p_addword, "Word", 0 );

  # panel addexample

  $self->p_addexample( Dict::Learn::Frame::AddExample->new( $self, $self->notebook, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ));

  $self->notebook->AddPage( $self->p_addexample, "Example", 0 );

  # panel: table of words

  $self->p_gridwords( Dict::Learn::Frame::GridWords->new( $self, $self->notebook, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ));
  $self->notebook->AddPage( $self->p_gridwords, "Words", 0 );

  # panel: table of examples

  $self->p_gridexamples( Dict::Learn::Frame::GridExamples->new( $self, $self->notebook, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ));
  $self->notebook->AddPage( $self->p_gridexamples, "Examples", 0 );

  # Irregular Verbs test
  $self->pt_irrverbs( Dict::Learn::Frame::IrregularVerbsTest->new($self, $self->notebook,
wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ));
  $self->notebook->AddPage( $self->pt_irrverbs, "Irregular Verbs Test", 0 );

  # tell we want automatic layout
  # $self->SetAutoLayout( 1 );
  $self->vbox->Add( $self->notebook, 1, wxALL|wxEXPAND, 5 );
  $self->SetSizer( $self->vbox );
  # size the window optimally and set its minimal size
  # $self->vbox->Fit( $self );
  # $self->vbox->SetSizeHints( $self );
  $self->status_bar($self->CreateStatusBar( 1, wxST_SIZEGRIP, wxID_ANY ));

  Dict::Learn::Dictionary->set(0);
  # set a frame title based on current dictionary
  # like 'DictLearn - [English-Ukrainian]'
  $self->set_frame_title();

  # events
  EVT_CLOSE( $self, \&on_close );
  $self
}

sub init_menu_dicts {
  my ($self, $menu) = @_;
  # Wx::MenuItem->new( $self->menu_dicts, wxID_ANY, "Test", "", wxITEM_NORMAL)
  for ( sort { $a->{dictionary_id} <=> $b->{dictionary_id} }
        values %{ Dict::Learn::Dictionary->all } )
  {
    $menu->AppendRadioItem( _MENU_ID($_->{dictionary_id}), $_->{dictionary_name} );
    # event
    EVT_MENU( $self, _MENU_ID($_->{dictionary_id}), \&dictionary_check );
  }
  $self
}

sub dictionary_check {
  my ($self, $event) = @_;
  # my $menu = $event->GetEventObject();
  my $menu_item = $self->menu_dicts->FindItem( $event->GetId );
  $self->status_bar->SetStatusText(
    "Dictionary '" . $menu_item->GetLabel . "' selected"
  );
  Dict::Learn::Dictionary->set( _DICT_ID($event->GetId) );
  $self->set_frame_title( _DICT_ID($event->GetId) );
}

sub set_frame_title {
  my ($self, $id) = @_;
  $id ||= Dict::Learn::Dictionary->curr_id;
  $self->SetTitle(sprintf 'DictLearn - [%s]',
                  Dict::Learn::Dictionary->get($id)->{dictionary_name});
}

sub _MENU_ID {
  my ($dict_id) = @_;
  int($dict_id) + DICT_OFFSET
}

sub _DICT_ID {
  my ($menu_id) = @_;
  int($menu_id) - DICT_OFFSET
}

sub on_close {
  my ( $self, $event ) = @_;
  print "exit\n";
  $self->Destroy;
}

sub export {
  my $self = shift;
  say "export";
}

sub import {
  my $self = shift;
  say "import";
}

1;
