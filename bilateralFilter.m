
function out = bilateralFilter( img, varargin )
  % out = bilateralFilter( img, [ 'S', S, 'sigmaD', sigmaD, 'sigmaR', sigmaR ] );
  %
  % Inputs
  %   img: the input image to be denoised
  %     either a MxN 2D grayscale image or a MxNx3 color image
  %
  % Optional Inputs:
  %   S: the length of each side of the kernel (must be odd)
  %   sigmaD: euclidean distance spread parameter
  %   sigmaR: photometric distance spread parameter
  %
  % Outputs
  %   out: the denoised image

  isPositiveAndOdd = @(x) (x>0) && (mod(x,2) == 1);
  isNumericAndPositive = @(x) isnumeric(x) && (x>0);

  defaultS = 17;
  defaultSigmaD = 3;
  defaultSigmaR = 0.3;
  p = inputParser;
  p.addRequired( 'img', @isnumeric );
  p.addParameter( 'S', defaultS, isPositiveAndOdd );
  p.addParameter( 'sigmaD', defaultSigmaD, isNumericAndPositive );
  p.addParameter( 'sigmaR', defaultSigmaR, isNumericAndPositive );
  p.parse( img, varargin{:} );
  s = p.Results.S;
  sigmaD = p.Results.sigmaD;
  sigmaR = p.Results.sigmaR;
  
  if ismatrix(img)
    out = bilateralFilter_2D( img, s, sigmaD, sigmaR );
  elseif ndims(img)==3
    out = bilateralFilter_3D( img, s, sigmaD, sigmaR );
  end
end


function out = bilateralFilter_2D( img, s, sigmaD, sigmaR )

  dKernel = fspecial( 'gaussian', s, sigmaD );
  halfS = floor(s/2);
  varR = sigmaR * sigmaR;

  sImg = size( img );
  jCells = cell( sImg(1), 1 );
  firstJ = ceil(s/2);
  lastJ = sImg(1)-floor(s/2);
  for j=1:sImg(1), jCells{j}=zeros(1,sImg(2)); end;
  p = parforProgress( lastJ-firstJ+1 );
  parfor j=firstJ:lastJ
    p.progress( j-firstJ+1, 50 );                                                                   %#ok<PFBNS>
    tmp = zeros( 1, sImg(2) );                                                             %#ok<PFBNS>
    imgLine = img( j-halfS:j+halfS, : );                                                   %#ok<PFBNS>

    for i=ceil(s/2):sImg(2)-floor(s/2)
      %subImg = img( j-halfS:j+halfS, i-halfS:i+halfS );
      subImg = imgLine( :, i-halfS : i+halfS );

      pKernel = exp( -( img(j,i) - subImg ).^2 / ( 2 * varR ) );

      weights = pKernel .* dKernel;
      weights = weights / sum( weights(:) );

      tmp(i) = sum( subImg(:) .* weights(:) );
    end
    jCells{j} = tmp;
  end
  out = cell2mat( jCells );
  p.clean;
end


function out = bilateralFilter_3D( img, s, sigmaD, sigmaR )

  dKernel = fspecial3d( 'gaussian', s, sigmaD );
  halfS = floor(s/2);
  varR = sigmaR * sigmaR;

  sImg = size( img );
  sliceCells = cell(1,1,sImg(3));
  firstK = ceil(s/2);
  lastK = sImg(3)-floor(s/2);
  for k=1:lastK, sliceCells{k} = zeros( sImg(1:2) ); end;
  p = parforProgress( lastK-firstK+1 );
  parfor k=firstK:lastK
    p.progress( k-firstK+1 );                                                              %#ok<PFBNS>
    tmp = zeros( sImg(1:2) );                                                              %#ok<PFBNS>
    kImg = img(:,:,k-halfS:k+halfS);                                                       %#ok<PFBNS>

    for j=ceil(s/2):sImg(1)-floor(s/2)
      for i=ceil(s/2):sImg(2)-floor(s/2)
        %subImg = img( j-halfS:j+halfS, i-halfS:i+halfS, k-halfS:k+halfS );
        subImg = kImg( j-halfS:j+halfS, i-halfS:i+halfS, : );

        pKernel = exp( -( img(j,i,k) - subImg ).^2 / ( 2 * varR ) );

        weights = pKernel .* dKernel;
        weights = weights / sum( weights(:) );

        tmp(j,i) = sum( subImg(:) .* weights(:) );
      end
    end
    sliceCells{1,1,k} = tmp;
  end
  p.clean;
  out = cell2mat( sliceCells );
end


