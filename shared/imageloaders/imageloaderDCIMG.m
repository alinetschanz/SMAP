classdef imageloaderDCIMG<interfaces.imageloaderSMAP
    %imageloaderMM image loader for micromanager single tiff files
    %  now implement with hacked DCIMG reader
    
    properties
        reader
        blocksize
        currentfile
        separate
        separatefiles
    end
    
    methods
        function obj=imageloaderDCIMG(varargin)
            obj@interfaces.imageloaderSMAP(varargin{:});
        end
        function openi(obj,file)
%             r=dcimgmex( 'open', file);
            r=dcimgReaderMatlab(file);
            obj.blocksize=r.metadata.num_frames;
%             obj.blocksize=double(dcimgmex('getparam',r,'NUMBEROF_FRAME'));
            [path,filen,ext]=fileparts(file);
            allfiles=dir([path filesep filen(1:end-3) '*' ext]);
            if length(allfiles)==1 %test of previous block is incremental
                ind=strfind(filen,'_');
                if length(ind)>1
                    allfiles=dir([path filesep filen(1:ind(end-1)) '*' filen(ind(end):end) ext]);
                end
            end
            
            obj.separate.numfiles=length(allfiles);
            [~,ind]=sort({allfiles(:).name});
            firstfile=allfiles(ind(1)).name;
            r.close;
%             dcimgmex('close', r);
            
            obj.file=[path filesep firstfile];
            obj.currentfile=1;
            for k=1:obj.separate.numfiles
                obj.reader{k}=dcimgReaderMatlab([path filesep allfiles(ind(k)).name]);
            end
            obj.getmetadata;
            
            obj.separate.path=path;
            obj.separatefiles={allfiles(ind).name};
        end

        function allmd=getmetadatatagsi(obj)
            
%             parameters={'SENSOR_BINNING', 'SENSOR_HPOS', 'SENSOR_HSIZE', 'SENSOR_VPOS', 'SENSOR_VSIZE',...
%                  'IMAGE_WIDTH', 'IMAGE_HEIGHT', 'IMAGE_ROWBYTES', 'IMAGE_PIXELTYPE', ...
%                  'NUMBEROF_TOTALFRAME', 'NUMBEROF_SESSION', 'NUMBEROF_FRAME',...
%                  'NUMBEROF_VIEW', 'NUMBEROF_REGIONRECT',...
%                  'CURRENT_SESSION', 'CURRENT_VIEW', 'CURRENT_REGIONRECT', 'FILEFORMAT_VERSION'};
%               for k=length(parameters):-1:1
%                   allmd{k,1}=parameters{k};
%                   allmd{k,2}=num2str((dcimgmex('getparam',obj.reader,parameters{k})));
%               end
              md=obj.reader{1}.metadata;
              fn=fieldnames(md);
              for k=1:length(fn)
                  allmd{k,1}=fn{k};
                  allmd{k,2}=md.(fn{k});
              end
              allmd{k+1,1}='numberOfFrames';
              allmd{k+1,2}=obj.blocksize*(obj.separate.numfiles-1)+obj.reader{end}.metadata.num_frames;
              allmd{k+2,1}='DCIMG-reader Hamamatsu Version';
              allmd{k+2,2}=num2str(md.format_version);
        end
        function image=getimagei(obj,frame)
            image=readseparate(obj,frame);
        end
        function closei(obj)
            for k=1:length(obj.reader)
            obj.reader{k}.close;
            end
%             dcimgmex('close', obj.reader);
        end
        function file= getbasefile(obj)
            file=getbasefile(obj.file);
        end
    end
    
end

function image=readseparate(obj,number)

filenumber=ceil(number/obj.blocksize);

if obj.onlineAnalysis &&  (filenumber<length(obj.separatefiles) || isempty(obj.separatefiles{filenumber})) %|| (ismethod(obj.separatefiles(filenumber),'ismissing') && obj.separatefiles(filenumber).ismissing))
    %file name not yet stored
%     lastfile= obj.separatefiles{obj.currentfile};
    thisname=generateFileName(obj,filenumber);
    thisfile=[obj.separate.path filesep thisname];
    if ~exist(thisfile,'file')
        disp('wait')
        pause(obj.waittime*2)
    end
    if ~exist(thisfile,'file')
        image=[];
        return
    else
        obj.separatefiles{filenumber}=thisname;
        obj.reader{filenumber}=dcimgReaderMatlab(thisfile);
        obj.metadata.numberOfFrames=max(length(obj.separatefiles{number})*obj.blocksize,number);
    end 
end

if filenumber>length(obj.reader)
    image=[];
    return
end
% if filenumber~=obj.currentfile
%     dcimgmex('close',obj.reader);
%     obj.reader=dcimgmex('open',[obj.separate.path filesep obj.separatefiles{filenumber}]);
%     obj.currentfile=filenumber;
% end
frame=mod(number,obj.blocksize)+1;

% try
%     image=transpose(dcimgmex( 'readframe', obj.reader, frame)); 
%    image=transpose(obj.reader{filenumber}.getSpecificFrames(frame));
     image=(obj.reader{filenumber}.getSpecificFrames(frame));
% catch err
%     err
%     pause(obj.waittime*2)
%     disp('error encountered rading image, try again');
% %     image=transpose(dcimgmex( 'readframe', obj.reader, frame));   
%     image=transpose(obj.reader{filenumber}.getSpecificFrames(frame));
% end
end

function newfile=generateFileName(obj,newfilenumber)
% if isempty(indfbar)
testfile=obj.separatefiles{1};
ind1=find(testfile~=obj.separatefiles{end},1,'first');
ind2=strfind(testfile(1:ind1),'_');ind2=ind2(end)+1;
ind3=strfind(testfile(ind2+1:end),'_');
if isempty(ind3) 
    ind3=strfind(testfile(ind2+1:end),'.'); 
end
ind3=ind3(1)-1;

num=str2double(testfile(ind2:ind2+ind3));
df=1-num;

newstr=num2str(newfilenumber-df,['%0' int2str(ind3+1) 'i']);
newfile=[testfile(1:ind2-1) newstr testfile(ind2+ind3+1:end)];
end