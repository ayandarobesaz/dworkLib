
function recon = mri_reconSparseSENSE( kData, sMaps, lambda, varargin )
  % recon = mri_reconSparseSENSE( kData, sMaps, lambda, [, 'img0', img0, 'nIter', nIter, ...
  %   'noiseCov', noiseCov ] )
  %
  % This routine uses proximal gradient methods to minimize
  %   0.5 * || A y - b ||_2^2 + lambda || y ||_{w,1}
  %   where A is sampleMask * Fourier Transform * adjoint( Psi ).  Here, Psi is either a wavelet or curvelet
  %   transform.  The reconstruction returned is adjoint( Psi ) * y.
  %
  % Note that || y ||_{w,1} = w1 |y1| + w2 |y2| + ... + wN |yN|
  %
  % Inputs:
  % kData - an array of size Ny x Nx x nCoils
  %
  % Outputs:
  % recon - a 2D complex array that is the image
  %
  % Written by Nicholas Dwork - Copyright 2019
  %
  % https://github.com/ndwork/dworkLib.git
  %
  % This software is offered under the GNU General Public License 3.0.  It
  % is offered without any warranty expressed or implied, including the
  % implied warranties of merchantability or fitness for a particular purpose.

  p = inputParser;
  p.addRequired( 'kData', @isnumeric );
  p.addRequired( 'sMaps', @isnumeric );
  p.addRequired( 'lambda', @ispositive );
  p.addParameter( 'checkAdjoints', false, @islogical );
  p.addParameter( 'debug', false, @(x) isnumeric(x) || islogical(x) );
  p.addParameter( 'img0', [], @isnumeric );
  p.addParameter( 'nIter', [], @ispositive );
  p.addParameter( 'noiseCov', [], @isnumeric );
  p.addParameter( 'optAlg', 'fista_wLS', @(x) true );
  p.addParameter( 'printEvery', 10, @ispositive );
  p.addParameter( 't', [], @ispositive );
  p.addParameter( 'transformType', 'wavelet', @(x) true );
  p.addParameter( 'verbose', false, @(x) isnumeric(x) || islogical(x) );
  p.addParameter( 'waveletType', 'Daubechies-4', @(x) true );
  p.addParameter( 'wavSplit', [], @isnumeric );
  p.parse( kData, sMaps, lambda, varargin{:} );
  checkAdjoints = p.Results.checkAdjoints;
  debug = p.Results.debug;
  img0 = p.Results.img0;
  nIter = p.Results.nIter;
  noiseCov = p.Results.noiseCov;
  optAlg = p.Results.optAlg;
  printEvery = p.Results.printEvery;
  t = p.Results.t;
  transformType = p.Results.transformType;
  waveletType = p.Results.waveletType;
  wavSplit = p.Results.wavSplit;
  verbose = p.Results.verbose;

  if numel( transformType ) == 0, transformType = 'wavelet'; end
  if numel( waveletType ) == 0, waveletType = 'Daubechies-4'; end

  if numel( nIter ) == 0
    if debug == true
      nIter = 30;
    else
      nIter = 100;
    end
  end

  sKData = size( kData );
  sImg = sKData(1:2);

  if numel( img0 ) == 0
    coilRecons = mri_reconIFFT( kData );
    img0 = mri_reconRoemer( coilRecons );
  end
  if numel( wavSplit ) == 0
    wavSplit = makeWavSplit( sImg );
  end

  function out = curvelet( x, type )
    if nargin < 2 || strcmp( type, 'notransp' )
      curvCells = fdct_wrapping( x, false );
      out = curvCell2Vec( curvCells );
    else
      curvCells = vec2CurvCell( x, curvCellSizes );
      out = ifdct_wrapping( curvCells, false );
    end
  end

  if strcmp( waveletType, 'Daubechies-4' )
    wavTrans = @(x) wtDaubechies2( x, wavSplit );
    wavTransH = @(y) iwtDaubechies2( y, wavSplit );
  elseif strcmp( waveletType, 'Haar' )
    wavTrans = @(x) wtHaar2( x, wavSplit );
    wavTransH = @(y) iwtHaar2( y, wavSplit );
  else
    error( 'Unrecognized wavelet type' );
  end

  function out = wavCurv( x, type )
    if nargin < 2 || strcmp( type, 'notransp' )
      x = reshape( x, sImg );
      wx = wavTrans( x );
      cx = curvelet( x );
      out = [ wx(:); cx(:); ];
    elseif strcmp( type, 'transp' )
      x1 = reshape( x( 1 : nImg ), sImg );
      x2 = x( nImg + 1 : end );
      out = wavTransH( x1 ) + curvelet( x2, 'transp' );
      out = out(:);
    end
  end

  if strcmp( transformType, 'curvelet' ) || strcmp( transformType, 'wavCurv' )
    tmp = fdct_wrapping( FH( samples ), false );
    curvCellSizes = findCellSizes( tmp );

    if strcmp( transformType, 'wavCurv' )
      sparsifier = @(x) wavCurv( x );
      sparsifierH = @(x) wavCurv( x, 'transp' );
    else
      sparsifier = @(x) curvelet( x );
      sparsifierH = @(x) curvelet( x, 'transp' );
    end

  elseif strcmp( transformType, 'wavelet' )
    sparsifier = wavTrans;
    sparsifierH = wavTransH;

  else
    error( 'Unrecognized transform type' );
  end

  function out = applyS( in, type )
    if nargin < 2 || strcmp( type, 'notransp' )
      out = bsxfun( @times, sMaps, in );
    else
      out = sum( conj(sMaps) .* in, 3 );
    end
  end

  function out = applyF( in, type )
    if nargin < 2 || strcmp( type, 'notransp' )
      out = fftshift2( fft2( ifftshift2( in ) ) );
    else
      out = fftshift2( fft2h( ifftshift2( in ) ) );
    end
  end

  function out = applySF( in, type )
    if nargin < 2 || strcmp( type, 'notransp' )
      out = applyF( applyS( in ) );
    else
      out = applyS( applyF( in, 'transp' ), 'transp' );
    end
  end

  dataMask = ( abs(kData) ~= 0 );
  function out = applyA( in, type )
    if nargin < 2 || strcmp( type, 'notransp' )
      PsiHin = sparsifierH( in );
      out = applySF( PsiHin );
      out = out( dataMask == 1 );
    else
      tmp = zeros( sKData );
      tmp( dataMask == 1 ) = in;
      in = tmp;  clear tmp;
      in = reshape( in, sKData );
      SFin = applySF( in .* dataMask, 'transp' );
      out = sparsifier( SFin );
    end
  end

  applyATA = @(x) applyA( applyA( x ), 'transp' );

  if numel( noiseCov ) > 0
    invNoiseCov = inv( noiseCov );
    [~,s,~] = svd( invNoiseCov, 'econ' );
    invNoiseCov = invNoiseCov ./ s(1);
    L = chol( invNoiseCov, 'lower' );
  end
  function out = applyL( in, type )
    if numel( noiseCov ) == 0, out = in; return; end

    % Assumes last dimension is coil dimension
    if nargin < 2, type = 'notransp'; end

    sIn = size( in );
    reshaped = reshape( in, [ prod( sIn(1:end-1) ) sIn(end) ] );
    if strcmp( type, 'notransp' )
      out = transpose( L * transpose( reshaped ) );
    else
      out = transpose( L' * transpose( reshaped ) );
    end
    out = reshape( out, sIn );
  end

  M = max( dataMask, [], 3 );
  nM = sum( M(:) );
  nCoils = sKData( ndims( kData ) );
  b = zeros( nM, nCoils );
  for coilIndx = 1 : nCoils
    coilSamples = kData( :, :, coilIndx );
    b( :, coilIndx ) = coilSamples( M == 1 );
  end
  b = b(:);
 
  function out = g( x )
    diff = applyA( x ) - b;
    if numel( noiseCov ) > 0
      NInvDiff = applyL( reshape( diff, [ nM nCoils ] ) );
      out = real( 0.5 * diff' * NInvDiff(:) );
    else
      out = 0.5 * norm( diff(:), 2 )^2;
    end
  end

  if numel( noiseCov ) > 0
    NInvb = applyL( reshape( b, [ nM nCoils ] ) );
    AadjMb = applyA( NInvb(:), 'transp' );
  else
    Aadjb = applyA( b, 'transp' );
  end
  function out = gGrad( x )
    if numel( noiseCov ) > 0
      Ax = applyA( x );
      NInvAx = applyL( reshape( Ax, [ nM nCoils ] ) );
      out = applyA( NInvAx(:), 'transp' ) - AadjMb;
    else
      out = applyA( applyA( x ), 'transp' ) - Aadjb;
    end
  end

  if checkAdjoints == true
    innerProd = @(x,y) real( dotP( x, y ) );
    [checkS,errS] = checkAdjoint( img0, @applyS, 'innerProd', innerProd );
    if checkS ~= 1, error( ['Adjoint of S failed with error ', num2str(errS) ]); end
    [checkF,errF] = checkAdjoint( repmat(img0,[1,1,8]), @applyF, 'innerProd', innerProd );
    if checkF ~= 1, error( ['Adjoint of F failed with error ', num2str(errF) ]); end
    [checkSF,errSF] = checkAdjoint( img0, @applySF, 'innerProd', innerProd );
    if checkSF ~= 1, error( ['Adjoint of SF failed with error ', num2str(errSF) ]); end
    [checkA,errA] = checkAdjoint( img0, @applyA, 'innerProd', innerProd );
    if checkA ~= 1, error( ['Adjoint of A failed with error ', num2str(errA) ]); end
    [checkW,errW] = checkAdjoint( imgRand, wavTrans, wavTransH );
    if checkW ~= 1, error( ['Adjoint of wavOp failed with error ', num2str(errW) ]); end
    [checkS,errS] = checkAdjoint( imgRand, sparsifier, sparsifierH );
    if checkS ~= 1, error( ['Adjoint of sparsifier failed with error ', num2str(errS) ]); end
  end

  if numel( lambda ) == 0
    psiRecon0 = sparsifier( img0 );
    lambda = 1 ./ ( abs( psiRecon0 ) + 1d-8 * max( abs( kData(:) ) ) );
  end

  function out = proxth( x, t )
    out = softThresh( x, t * lambda );
  end

  function out = h( x )
    Wx = sparsifier(x);
    out = sum( lambda .* abs( Wx(:) ) );
  end

  if numel( t ) == 0
    normATA = powerIteration( applyATA, rand( size( img0 ) ), 'symmetric', true );
    if normATA == 0
      % A just sets everything to 0
      recon = zeros( size( img0 ) );
      oValues = g( recon ) * ones( nIter, 1 );   %#ok<NASGU>
      return;
    end

    t = 0.99 / normATA;
  end


  if debug
    if strcmp( optAlg, 'fista' )
      [psiRecon,oValues,relDiffs] = fista( img0, @gGrad, @proxth, 't', t, ...
        'g', @g, 'h', @h, 'printEvery', printEvery, 'verbose', verbose );   %#ok<ASGLU>
    elseif strcmp( optAlg, 'fista_wLS' )
      t = t * 10;
      [psiRecon,oValues] = fista_wLS( img0, @g, @gGrad, @proxth, 'h', @h, ...
        't0', t, 'N', nIter, 'restart', true, 'verbose', true, 'printEvery', printEvery );   %#ok<ASGLU>
    elseif strcmp( optAlg, 'pogm' )
      [psiRecon,oValues] = pogm( img0, @gGrad, @proxth, nIter, 't', t, 'g', @g, 'h', @h, ...
        'printEvery', printEvery, 'verbose', true );   %#ok<ASGLU>
    else
      error([ 'Unrecognized optAlg: ', optAlg ]);
    end
  else
    if strcmp( optAlg, 'fista' )
      psiRecon = fista( img0, @gGrad, @proxth, 't', t, 'printEvery', printEvery, 'verbose', true );
    elseif strcmp( optAlg, 'fista_wLS' )
      t = t * 10;
      psiRecon = fista_wLS( img0, @g, @gGrad, @proxth, 't0', t, 'N', nIter, ...
        'restart', true, 'verbose', verbose, 'printEvery', printEvery );
    elseif strcmp( optAlg, 'pogm' )
      psiRecon = pogm( img0, @gGrad, @proxth, nIter, 't', t, 'g', @g, 'h', @h, ...
        'printEvery', printEvery, 'verbose', verbose );
    else
      error([ 'Unrecognized optAlg: ', optAlg ]);
    end
  end

  recon = reshape( sparsifierH( psiRecon ), sImg );
end


function out = findCellSizes( in )
  if iscell( in )
    out = cell( size(in) );
    for indx = 1 : numel( in )
      theseCellSizes = findCellSizes( in{ indx } );
      out{ indx } = theseCellSizes;
    end
  else
    out = size( in );
  end
end

function nTotal = sumCurvCellSizes( cellSizes )
  nTotal = 0;
  if iscell( cellSizes )
    for indx = 1 : numel( cellSizes )
      thisCell = cellSizes{ indx };  
      nTotal = nTotal + sumCurvCellSizes( thisCell );
    end
  else
    nTotal = nTotal + prod( cellSizes );
  end
end

function out = curvCell2Vec( cx )
  if iscell( cx )
    out = cell( numel( cx ), 1 );
    for indx = 1 : numel( cx )
      out{ indx } = curvCell2Vec( cx{ indx } );
    end
    out = cell2mat( out );
  else
    out = cx(:);
  end
end

function out = vec2CurvCell( v, curvCellSizes )
  if iscell( curvCellSizes )
    out = cell( size( curvCellSizes ) );
    thisIndx = 1;
    for indx = 1 : numel( curvCellSizes )
      nSubVec = sumCurvCellSizes( curvCellSizes{ indx } );
      subVec = v( thisIndx : thisIndx + nSubVec - 1 );
      out{ indx } = vec2CurvCell( subVec, curvCellSizes{ indx } );
      thisIndx = thisIndx + nSubVec;
    end
  else
    out = reshape( v, curvCellSizes );
  end
end


function wavSplit = makeWavSplit( sImg )

  minSplit = 8;

  yTmp = sImg(1);
  ySplitSize = 1;
  while ( mod( yTmp, 1 ) == 0 )
    ySplitSize = ySplitSize * 2;
    yTmp = yTmp / 2;
  end
  ySplitSize = ySplitSize / 4;
  ySplitSize = min( ySplitSize, minSplit );

  xTmp = sImg(2);
  xSplitSize = 1;
  while ( mod( xTmp, 1 ) == 0 )
    xSplitSize = xSplitSize * 2;
    xTmp = xTmp / 2;
  end
  xSplitSize = xSplitSize / 4;
  xSplitSize = min( xSplitSize, minSplit );

  wavSplit = zeros( [ ySplitSize xSplitSize ] );
  wavSplit(1) = 1;
end


