function [filename,folder] = quicklab_save_target(EEG,suffix)
% QUICKLAB_SAVE_TARGET Construct a filename without truncating unsaved names.
if isstring(suffix) && isscalar(suffix), suffix = char(suffix); end
if ~ischar(suffix) || size(suffix,1) > 1 || any(ismember(suffix,'<>:"/\|?*')) || any(double(suffix)<32)
    error('QuickLab:InvalidSuffix','The filename addition cannot contain slashes or reserved filename characters.');
end
if isempty(EEG.filename)
    name = EEG.setname;
    if isempty(name), name = 'dataset'; end
    name = regexprep(name,'[<>:"/\\|?*\x00-\x1f]','_');
else
    [~,name] = fileparts(EEG.filename);
end
filename = [name suffix '.set'];
folder = EEG.filepath;
end
