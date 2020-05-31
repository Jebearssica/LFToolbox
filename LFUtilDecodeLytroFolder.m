% LFUtilDecodeLytroFolder - decode and optionally colour correct and rectify Lytro light fields
%
% Usage:
%
%     LFUtilDecodeLytroFolder
%     LFUtilDecodeLytroFolder( InputPath )
%     LFUtilDecodeLytroFolder( InputPath, FileOptions, DecodeOptions, RectOptions )
%     LFUtilDecodeLytroFolder( InputPath, [], [], RectOptions )
%
% All parameters are optional and take on default values as set in the "Defaults" section at the top
% of the implementation. As such, this can be called as a function or run directly by editing the
% code. When calling as a function, pass an empty array "[]" to omit a parameter.
%
% As released, the default values are set up to match the naming conventions of LFP Reader v2.0.0.
%
% This function demonstrates decoding and optionally colour-correction and rectification of 2D
% lenslet images into 4D light fields. It recursively crawls through a prescribed folder and its
% subfolders, operating on each light field. It can be used incrementally: previously-decoded light
% fields can be subsequently colour-corected, rectified, or both. Previously-completed tasks will
% not be re-applied. A filename pattern can be provided to work on individual files. All paths and
% naming are configurable.
%
% Decoding and rectification follow the process described in:
%
% [1] D. G. Dansereau, O. Pizarro, and S. B. Williams, "Decoding, calibration and rectification for
% lenslet-based plenoptic cameras," in Computer Vision and Pattern Recognition (CVPR), IEEE
% Conference on. IEEE, Jun 2013.
%
% Decoding requires that an appropriate database of white images be created using
% LFUtilProcessWhiteImages. Rectification similarly requires a calibration database created using
% LFUtilProcessCalibrations.
% 
% To decode a single light field, it is simplest to include a file specification in InputPath (see
% below). It is also possible to call LFLytroDecodeImage directly.
%
% Colour correction employs the metadata associated with each Lytro picture. It also applies
% histogram-based contrast adjustment. It calls the functions LFColourCorrect and LFHistEqualize.
%
% Rectification employs a calibration info file to rectify the light field, correcting for lens
% distortion, making pixels square, and yielding an intrinsics matrix which allows easy conversion
% from a pixel index [i,j,k,l] to a ray [s,t,u,v]. A calibration info file is generated by
% processing a series of checkeboard images, following the calibration procedure described in
% LFToolbox.pdf. A calibration only applies to one specific camera at one specific zoom and focus
% setting, and decoded using one specific lenslet grid model. The tool LFUtilProcessCalibrations is
% used to build a database of rectifications, and LFSelectFromDatabase isused to select a
% calibration appropriate to a given light field.
%
% This function was written to deal with Lytro imagery, but adapting it to operate with other
% lenslet-based cameras should be straightforward. For more information on the decoding process,
% refer to LFDecodeLensletImageDirect, [1], and LFToolbox.pdf.
%
% Some optional parameters are not used or documented at this level -- see each of LFCalRectifyLF,
% LFLytroDecodeImage, LFDecodeLensletImageDirect, and LFColourCorrect for further information.
%
%
% Inputs -- all are optional, see code below for default values :
%
%     InputPath :  Path to folder containing light fields, or to a specific light field, optionally including one or
%     more wildcard filename specifications. In case wildcards are used, this searches sub-folders recursively. See
%     LFFindFilesRecursive.m for more information and examples of how InputPath is interpreted.
%
%     FileOptions : struct controlling file naming and saving
%               .OutputPath : By default files are saved alongside input files; specifying an output
%                             path will mirror the folder structure of the input, and save generated
%                             files in that structure, leaving the input untouched
%          .OutputPrecision : 'uint8' or 'uint16', default 'uint16'
%             .OutputFormat : Output file format: default 'mat', can also be 'eslf.png' or
%                            'eslf.jpg'
%           .ImwriteOptions : Cell array of additional options to pass to imwrite for eslf output
%                             formats; see LFWriteESLF
%               .SaveWeight : Save the weight channel, default true
%               .SaveResult : Set to false to perform a "dry run"
%                .ForceRedo : If true previous results are ignored and decoding starts from scratch
%         .SaveFnamePattern : String defining the pattern used in generating the output filename;
%                             sprintf is used to complete this pattern, such that %s gets replaced
%                             with the base name of the input light field
%        .ThumbFnamePattern : As with SaveFnamePattern, defines the name of the output thumbnail
%                             image
%
%     DecodeOptions : struct controlling the decoding process, see LFDecodeLensletImageDirect for more info
%                    .OptionalTasks : Cell array containing any combination of 'ColourCorrect' and
%                                     'Rectify'; an empty array "{}" means no additional tasks are
%                                     requested; case sensitive
%         .LensletImageFnamePattern : Pattern used to locate input files -- the pattern %s stands in
%                                     for the base filename
%                 .ColourHistThresh : Threshold used by LFHistEqualize in optional colour correction
%           .WhiteImageDatabasePath : Path to the white images database, as created by
%                                     LFUtilProcessWhiteImages. Default is relative path 'Cameras'.
%                                     This can include the filename or only specify a path. The
%                                     toolbox will search folders recursively for a file with the
%                                     name WhiteImageDatabaseFname. If exactly one exists in the
%                                     specified folder structure, it will be used.
%          .WhiteImageDatabaseFname : Filename of the white image database, default WhiteImageDatabase.json
%                          .DoDehex : Controls whether hexagonal sampling is converted to rectangular, default true
%                       .DoSquareST : Controls whether s,t dimensions are resampled to square pixels, default true
%                     .ResampMethod : 'fast'(default)
%                                     'triangulation'
%                                     'barycentric': slower but generates larger images by a factor 3*sqrt(3)/2.
%                                     'none': No interpolation -> Generates many incomplete views with a weight map per RGB component (zero weight indicate missing pixel).
%                      .LevelLimits : a two-element vector defining the black and white levels
%                        .Precision : 'single'(default) or 'double'
%                 .WeightedDemosaic : Do White Image guided demosaicing, default=false.
%                   .WeightedInterp : Do White Image guided interpolations for lenslet image rotation/translation/scaling operations, default=false.
%              .ColourCompatibility : Keep same colours/exposure as versions v0.4 and v0.5 of the toolbox, default true
%               .NormaliseWIColours : Normalise sensor responses of Red and Blue pixels realtively to Green pixels in the White Image (prevents interference betweeen devignetting and white balance settings).
%                                     The option is true by default. But it is always desactivated when ColourCompatibility is true, to avoid changing colours compared to versions v0.4 and v0.5.
%              .NormaliseWIExposure : Normalises White image exposure to have value 1 at microlens centers (prevents interference between devignetting and exposure settings).
%                                     The option is true by default. But it is always desactivated when ColourCompatibility is true, to avoid changing exposure compared to versions v0.4 and v0.5.
%                .EarlyWhiteBalance : Perform white balance directly on the RAW data, before demosaicing, default = false.
%                 .CorrectSaturated : Process saturated pixels on the sensor so that they appear white after white balance, default = false.
%                         .ClipMode : Clipping for highlights : 'hard', 'soft' or 'none'. The default is 'soft' if CorrectSaturated is true, and 'hard' otherwise.
%                                     ClipMode='none' prevents clipping of highlights. To retain values above the saturation level in the output integer format,
%                                     the light field data is divided by its maximum value before conversion to integers, and the maximum value is saved in metadata as MaxLum.
%
%     RectOptions : struct controlling the optional rectification process
%         .CalibrationDatabasePath  : Path to the calibration file database, as created by
%                                     LFUtilProcessCalibrations; Default takes vale of
%                                     DecodeOptions.WhiteImageDatabasePath. This can include the
%                                     filename or only specify a path. The toolbox will search
%                                     folders recursively for a file with the name
%                                     CalibrationDatabaseFname. If exactly one exists in the
%                                     specified folder structure, it will be used.
%        .CalibrationDatabaseFname  : Filename of the calibration database, default CalibrationDaatabase.json
%
% Examples:
%
%   LFUtilDecodeLytroFolder
%
%     Run from the top level of the 'Samples' folder will decode all the light fields in all the
%     sub-folders, with default settings as set up in the opening section of the code. The
%     calibration database created by LFUtilProcessWhiteImages is expected to be in
%     'Cameras/CaliCalibrationDatabase.json' by default.
%
%   LFUtilDecodeLytroFolder('Images', [], struct('OptionalTasks', 'ColourCorrect'))
%
%     Run from the top level of the 'Samples' folder will decode and colour correct all light fields in the Images
%     folder and its sub-folders.
%
%   DecodeOptions.OptionalTasks = {'ColourCorrect', 'Rectify'};
%   LFUtilDecodeLytroFolder([], [], DecodeOptions)
%
%     Will perform both colour correction and rectification in the Images folder.
%
%   LFUtilDecodeLytroFolder('Images/Illum/Lorikeet.lfp')
%   LFUtilDecodeLytroFolder('Lorikeet.lfp')
%   LFUtilDecodeLytroFolder({'Images', '*Hiding*', 'Jacaranda*'})
%   LFUtilDecodeLytroFolder('*.raw')
%   LFUtilDecodeLytroFolder({'*0002*', '*0003*'})
%
%     Any of these, run from the top level of the 'Samples' folder, will decode the matching files.  See
%     LFFindFilesRecursive.
% 
%   LFUtilDecodeLytroFolder([],[],struct('WhiteImageDatabasePath','path/to/processed/cameras'))
% 
%     Specify an alternative location for the white images normally located in 'Cameras'. See 
%     LFUtilProcessWhiteImages for more examples.
% 
%   LFUtilDecodeLytroFolder([],struct('OutputPath','path/for/processed/images'))
% 
%     Specify an output path; input path structure will be mirrored and populated with decoded light
%     fields.
%
% User guide: <a href="matlab:which LFToolbox.pdf; open('LFToolbox.pdf')">LFToolbox.pdf</a>
% See also: LFUtilExtractLFPThumbs, LFUtilProcessWhiteImages, LFUtilProcessCalibrations, LFUtilCalLensletCam,
% LFColourCorrect, LFHistEqualize, LFFindFilesRecursive, LFLytroDecodeImage, LFDecodeLensletImageDirect,
% LFSelectFromDatabase

% Copyright (c) 2013-2020 Donald G. Dansereau

function LFUtilDecodeLytroFolder( InputPath, FileOptions, DecodeOptions, RectOptions )

%---Defaults---
InputPath = LFDefaultVal( 'InputPath', 'Images' );

FileOptions = LFDefaultField('FileOptions', 'OutputPrecision', 'uint16' );
FileOptions = LFDefaultField('FileOptions', 'OutputFormat', 'mat' );
FileOptions = LFDefaultField('FileOptions', 'ImwriteOptions', {} );
FileOptions = LFDefaultField('FileOptions', 'SaveWeight', true );
FileOptions = LFDefaultField('FileOptions', 'SaveResult', true);
FileOptions = LFDefaultField('FileOptions', 'ForceRedo', false);
FileOptions = LFDefaultField('FileOptions', 'SaveFnamePattern', '%s__Decoded');
FileOptions = LFDefaultField('FileOptions', 'ThumbFnamePattern', '%s__Decoded_Thumb.png');

DecodeOptions = LFDefaultField('DecodeOptions', 'OptionalTasks', {}); % 'ColourCorrect', 'Rectify'
DecodeOptions = LFDefaultField('DecodeOptions', 'ColourHistThresh', 0.01);

DecodeOptions = LFDefaultField('DecodeOptions', 'WhiteImageDatabaseFname', 'WhiteImageDatabase.json');
DecodeOptions = LFDefaultField('DecodeOptions', 'WhiteImageDatabasePath', 'Cameras');
DecodeOptions.WhiteImageDatabasePath = ...
	LFLocateDatabaseFile( DecodeOptions.WhiteImageDatabasePath, DecodeOptions.WhiteImageDatabaseFname );

DecodeOptions = LFDefaultField( 'DecodeOptions', 'ColourCompatibility', true );
if( DecodeOptions.ColourCompatibility )
    DecodeOptions.NormaliseWIColours = false;
    DecodeOptions.NormaliseWIExposure = false;
end

if(isfield(DecodeOptions,'ResampMethod') && strcmp(DecodeOptions.ResampMethod,'none') && ~strcmp(FileOptions.OutputFormat,'mat'))
    warning('Only ''mat'' file OutputFormat is available with ResampMethod option set to ''none'' -> Using ''mat'' output format.');
    FileOptions.OutputFormat = 'mat';
end

RectOptions = LFDefaultField('RectOptions', 'CalibrationDatabaseFname', 'CalibrationDatabase.json');
RectOptions = LFDefaultField('RectOptions', 'CalibrationDatabasePath', fileparts(DecodeOptions.WhiteImageDatabasePath));

% Used to decide if two lenslet grid models are "close enough"... if they're not a warning is raised
RectOptions = LFDefaultField( 'RectOptions', 'MaxGridModelDiff', 1e-5 );

% Massage a single-element OptionalTasks list to behave as a cell array
while( ~iscell(DecodeOptions.OptionalTasks) )
	DecodeOptions.OptionalTasks = {DecodeOptions.OptionalTasks};
end

%---Crawl folder structure locating raw lenslet images---
DefaultFileSpec = {'*.lfr', '*.lfp', '*.LFR', '*.raw'}; % gets overriden below, if a file spec is provided
DefaultPath = 'Images';
fprintf('Input from %s\n', InputPath);

% Find input files
[FileList, BasePath] = LFFindFilesRecursive( InputPath, DefaultFileSpec, DefaultPath );

fprintf('Found :\n');
disp(FileList)

FileOptions = LFDefaultField('FileOptions', 'OutputPath', BasePath );
fprintf('Output to %s\n', FileOptions.OutputPath);

% create output folder; better to have a write permissions error here than after a full decode
warning('off','MATLAB:MKDIR:DirectoryExists');
mkdir( FileOptions.OutputPath );

%---Process each raw lenslet file---
% Store options so we can reset them for each file
OrigDecodeOptions = DecodeOptions;
OrigRectOptions = RectOptions;

for( iFile = 1:length(FileList) )
	SaveRequired = false;
	
	%---Start from orig options, avoids values bleeding between iterations---
	DecodeOptions = OrigDecodeOptions;
	RectOptions = OrigRectOptions;
	
	%---Find current / base filename---
	CurFname = FileList{iFile};
	
	% Build filename base without extension, auto-remove '__frame' for legacy .raw format
	LFFnameBase = CurFname;
	[~,~,Extension] = fileparts(LFFnameBase);
	LFFnameBase = LFFnameBase(1:end-length(Extension));
	CullIdx = strfind(LFFnameBase, '__frame');
	if( ~isempty(CullIdx) )
		LFFnameBase = LFFnameBase(1:CullIdx-1);
	end
	
	fprintf('\n---%s [%d / %d]...\n', CurFname, iFile, length(FileList));
	
	%---Decode---
	fprintf('Decoding...\n');
	
	% First check if a decoded file already exists
	[SDecoded, FileExists, CompletedTasks, TasksRemaining, SaveFname] = CheckIfExists( ...
		LFFnameBase, DecodeOptions, FileOptions, FileOptions.ForceRedo );
	
	if( ~FileExists )
		% No previous result, decode
		InputFname = fullfile(BasePath, CurFname);
		[LF, LFMetadata, WhiteImageMetadata, LensletGridModel, DecodeOptions] = ...
			LFLytroDecodeImage( InputFname, DecodeOptions );
		if( isempty(LF) )
			continue;
		end
		fprintf('Decode complete\n');
		SaveRequired = true;
	elseif( isempty(TasksRemaining) )
		% File exists, and nothing more to do
		continue;
	else
		% File exists and tasks remain: unpack previous decoding results
		[LF, LFMetadata, WhiteImageMetadata, LensletGridModel, DecodeOptions] = LFStruct2Var( ...
			SDecoded, 'LF', 'LFMetadata', 'WhiteImageMetadata', 'LensletGridModel', 'DecodeOptions' );
		clear SDecoded
	end
	
	%---Display thumbnail---
	Thumb = DispThumb(LF, CurFname, CompletedTasks);
	
	%---Optionally colour correct---
	if( ismember( 'ColourCorrect', TasksRemaining ) )
		LF = ColourCorrect( LF, LFMetadata, DecodeOptions );
		CompletedTasks = [CompletedTasks, 'ColourCorrect'];
		SaveRequired = true;
		fprintf('Done\n');
		
		%---Display thumbnail---
		Thumb = DispThumb(LF, CurFname, CompletedTasks);
	end
	
	%---Optionally rectify---
	if( ismember( 'Rectify', TasksRemaining ) )
		RectOptions.CalibrationDatabasePath = ...
			LFLocateDatabaseFile( RectOptions.CalibrationDatabasePath, RectOptions.CalibrationDatabaseFname );
		[LF, RectOptions, Success] = Rectify( LF, LFMetadata, DecodeOptions, RectOptions, LensletGridModel );
		if( Success )
			CompletedTasks = [CompletedTasks, 'Rectify'];
			SaveRequired = true;
		end
		%---Display thumbnail---
		Thumb = DispThumb(LF, CurFname, CompletedTasks);
	end
	
	%---Check that all tasks are completed---
	UncompletedTaskIdx = find(~ismember(TasksRemaining, CompletedTasks));
	if( ~isempty(UncompletedTaskIdx) )
		UncompletedTasks = [];
		for( i=UncompletedTaskIdx )
			UncompletedTasks = [UncompletedTasks, ' ', TasksRemaining{UncompletedTaskIdx}];
		end
		warning(['Could not complete all tasks requested in DecodeOptions.OptionalTasks: ', UncompletedTasks]);
	end
	
	DecodeOptions.OptionalTasks = CompletedTasks;
	
	%---Optionally save---
	if( SaveRequired && FileOptions.SaveResult )
		% Convert to ints
		if(strcmp(DecodeOptions.ClipMode,'none'))
			MaxLum = max(LF(:));
		else
			MaxLum=1;
        end
		LF = LFConvertToInt( LF ./ MaxLum, FileOptions.OutputPrecision);
		
		% Strip weight if we don't want it
		% todo[optimization]: don't decode weight if it's not wanted
		if( ~FileOptions.SaveWeight )
			LF = LF( :,:,:,:, 1:3 );
		end

		% make sure output folder exists
		OutPath = fileparts(SaveFname);
		warning('off','MATLAB:MKDIR:DirectoryExists');
		mkdir( OutPath );

		ThumbFname = sprintf(FileOptions.ThumbFnamePattern, LFFnameBase);
		ThumbFname = fullfile(FileOptions.OutputPath, ThumbFname);
		fprintf('Saving to:\n\t%s,\n\t%s...\n', SaveFname, ThumbFname);
		TimeStamp = datestr(now,'ddmmmyyyy_HHMMSS');
		GeneratedByInfo = struct('mfilename', mfilename, 'time', TimeStamp, 'VersionStr', LFToolboxVersion);

		imwrite(Thumb, ThumbFname);
		switch( FileOptions.OutputFormat )
			case 'mat'
				save('-v7.3', SaveFname, 'GeneratedByInfo', 'LF', 'LFMetadata', 'WhiteImageMetadata', 'LensletGridModel', 'DecodeOptions', 'RectOptions', 'MaxLum');
			case 'eslf.png'
				WriteAlpha = FileOptions.SaveWeight;
				LFWriteESLF( LF, SaveFname, WriteAlpha, FileOptions.ImwriteOptions{:} );
				MetadataFname = [SaveFname, '.json'];
				LFWriteMetadata( MetadataFname, LFVar2Struct(GeneratedByInfo, LFMetadata, WhiteImageMetadata, LensletGridModel, DecodeOptions, RectOptions, MaxLum));
			case 'eslf.jpg'
				WriteAlpha = false;
				LFWriteESLF( LF, SaveFname, WriteAlpha, FileOptions.ImwriteOptions{:} );
				MetadataFname = [SaveFname, '.json'];
				LFWriteMetadata( MetadataFname, LFVar2Struct(GeneratedByInfo, LFMetadata, WhiteImageMetadata, LensletGridModel, DecodeOptions, RectOptions, MaxLum));
			otherwise
				error('Unrecognized output format %s', FileOptions.OutputFormat);
		end
	end
end
end

%---------------------------------------------------------------------------------------------------
function  [SDecoded, FileExists, CompletedTasks, TasksRemaining, SaveFname] = ...
	CheckIfExists( LFFnameBase, DecodeOptions, FileOptions, ForceRedo )

SDecoded = [];
FileExists = false;
SaveFname = sprintf(FileOptions.SaveFnamePattern, LFFnameBase);
SaveFname = [SaveFname, '.', FileOptions.OutputFormat];
SaveFname = fullfile(FileOptions.OutputPath, SaveFname);

if( ~ForceRedo && exist(SaveFname, 'file') )
	%---Task previously completed, check if there's more to do---
	FileExists = true;
	fprintf( '    %s already exists\n', SaveFname );
		
	switch( FileOptions.OutputFormat )
		case 'mat'
			PrevDecodeOptions = load( SaveFname, 'DecodeOptions' );
			PrevOptionalTasks = PrevDecodeOptions.DecodeOptions.OptionalTasks;
		otherwise
			MetadataFname = [SaveFname, '.json'];
			PrevDecodeOptions = LFReadMetadata( MetadataFname );
			PrevOptionalTasks = PrevDecodeOptions.DecodeOptions.OptionalTasks;
			if( ~isempty(PrevOptionalTasks) )
				PrevOptionalTasks = cellstr(PrevOptionalTasks);
			else
				PrevOptionalTasks = {};
			end
	end
	
	CompletedTasks = PrevOptionalTasks;
	TasksRemaining = find(~ismember(DecodeOptions.OptionalTasks, PrevOptionalTasks));
	if( ~isempty(TasksRemaining) )
		%---Additional tasks remain---
		TasksRemaining = {DecodeOptions.OptionalTasks{TasksRemaining}};  % by name
		fprintf('    Additional tasks remain, loading existing file...\n');
		
		switch( FileOptions.OutputFormat )
			case 'mat'
				SDecoded = load( SaveFname );
			otherwise
				SDecoded = LFReadMetadata( MetadataFname );
				LensletSize_pix = SDecoded.DecodeOptions.LFSize(1:2);
				LoadAlpha = FileOptions.SaveWeight;
				SDecoded.LF = LFReadESLF( SaveFname, LensletSize_pix, LoadAlpha );
		end
		AllTasks = [SDecoded.DecodeOptions.OptionalTasks, TasksRemaining];
		SDecoded.DecodeOptions.OptionalTasks = AllTasks;
		
		%---Convert to float as this is what subsequent operations require---
		OrigClass = class(SDecoded.LF);
		SDecoded.LF = cast( SDecoded.LF, SDecoded.DecodeOptions.Precision ) ./ ...
			cast( intmax(OrigClass), SDecoded.DecodeOptions.Precision );
		fprintf('Done\n');
	else
		%---No further tasks... move on---
		fprintf( '    No further tasks requested\n');
		TasksRemaining = {};
	end
else
	%---File doesn't exist, all tasks remain---
	TasksRemaining =  DecodeOptions.OptionalTasks;
	CompletedTasks = {};
end
end

%---------------------------------------------------------------------------------------------------
function Thumb = DispThumb( LF, CurFname, CompletedTasks)
Thumb = squeeze(LF(round(end/2),round(end/2),:,:,:)); % including weight channel for hist equalize
Thumb = uint8(LFHistEqualize(Thumb).*double(intmax('uint8')));
Thumb = Thumb(:,:,1:3); % strip off weight channel
LFDispSetup(Thumb);
Title = CurFname;

for( i=1:length(CompletedTasks) )
	Title = [Title, ', ', CompletedTasks{i}];
end

title(Title, 'Interpreter', 'none');
drawnow
end

%---------------------------------------------------------------------------------------------------
function LF = ColourCorrect( LF, LFMetadata, DecodeOptions )
fprintf('Applying colour correction... ');

%---Weight channel is not used by colour correction, so strip it out---
LFWeight = LF(:,:,:,:,DecodeOptions.NColChans+1:DecodeOptions.NColChans+DecodeOptions.NWeightChans);
LF = LF(:,:,:,:,1:DecodeOptions.NColChans);

if( DecodeOptions.EarlyWhiteBalance )
    ColBalance = [1 1 1]; %White Balance is already performed
else
    ColBalance = DecodeOptions.ColourBalance;
end

if(strcmp(DecodeOptions.ResampMethod,'none'))
    ColMatrix = eye(3); %Skip colour transform to avoid mixing RGB data since at most one component per pixel is reliable.
else
    ColMatrix = DecodeOptions.ColourMatrix;
end

if( DecodeOptions.ColourCompatibility )
    SaturationLevel = DecodeOptions.ColourBalance*DecodeOptions.ColourMatrix;
    SaturationLevel = min(SaturationLevel);
else
    SaturationLevel = 1;
end

doClip = ~strcmp(DecodeOptions.ClipMode,'none');

%---Apply the color conversion and saturate---
LF = LFColourCorrect( LF, ColMatrix, ColBalance, DecodeOptions.Gamma, SaturationLevel, doClip );

%---Put the weight channel back---
LF(:,:,:,:,DecodeOptions.NColChans+1:DecodeOptions.NColChans+DecodeOptions.NWeightChans) = LFWeight;

end

%---------------------------------------------------------------------------------------------------
function [LF, RectOptions, Success] = Rectify( LF, LFMetadata, DecodeOptions, RectOptions, LensletGridModel )
Success = false;
fprintf('Applying rectification... ');
%---Load cal info---
fprintf('Selecting calibration...\n');

[CalInfo, RectOptions] = LFFindCalInfo( LFMetadata, RectOptions );
if( isempty( CalInfo ) )
	warning('No suitable calibration found, skipping');
	return;
end

%---Compare structs
a = CalInfo.LensletGridModel;
b = LensletGridModel;
a.Orientation = strcmp(a.Orientation, 'horz');
b.Orientation = strcmp(b.Orientation, 'horz');
FractionalDiff = abs( (struct2array(a) - struct2array(b)) ./ struct2array(a) );
if( ~all( FractionalDiff < RectOptions.MaxGridModelDiff ) )
	warning(['Lenslet grid models differ -- ideally the same grid model and white image are ' ...
		' used to decode during calibration and rectification']);
end

%---Perform rectification---
[LF, RectOptions] = LFCalRectifyLF( LF, CalInfo, RectOptions );
Success = true;
end

