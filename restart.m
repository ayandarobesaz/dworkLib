
function restart( varargin )
  % restart
  %
  % closes all windows, clears variables, clears the command window, ends debug
  % mode, and deletes any parforProgess files that were created by the current
  % instance of Matlab
  %
  % Written by Nicholas Dwork - Copyright 2017
  %
  % https://github.com/ndwork/dworkLib.git
  %
  % This software is offered under the GNU General Public License 3.0.  It
  % is offered without any warranty expressed or implied, including the
  % implied warranties of merchantability or fitness for a particular
  % purpose.

  p = inputParser;
  p.addOptional( 'type', [], @(x) true );
  p.parse( varargin{:} );
  type = p.Results.type;

  if strcmp( type, 'all' )
    evalin( 'base', 'clear all' );  % delete all variables in global scope
    evalin( 'caller', 'clear all' );  % delete all variables in global scope
    clear all;  %#ok<CLALL>

    if parpoolExists(), delete( gcp ); end

    parforFiles = dir( 'parforProgress*.txt' );
    for fileIndx = 1 : numel( parforFiles )
      delete( parforFiles(fileIndx).name );
    end

  elseif numel( type ) == 0
    pid = feature('getpid');
    parforProgressFile = ['parforProgress_', num2str(pid), '.txt'];
    if exist( parforProgressFile, 'file' )
      delete( parforProgressFile );
    end

  else
    error( 'Unknown argument passed to restart' );
  end

  close all;  clc;  clear;  clear global;

  % I would like to be able to call 'dbquit' here, but Matlab
  % prevents it.  So instead, I must simulate keyboard commands,
  % which is what is done here:
  pressShiftF5;
  evalin( 'base', 'clear all' );
end


function pressShiftF5
  import java.awt.Robot;
  import java.awt.event.KeyEvent;

  rob = Robot;  %Create a Robot-object to do the key-pressing
  rob.keyPress( KeyEvent.VK_SHIFT );
  rob.keyPress( KeyEvent.VK_F5 );
  pause( 0.02 );
  rob.keyRelease( KeyEvent.VK_F5 );
  rob.keyRelease( KeyEvent.VK_SHIFT );
end


