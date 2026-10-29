function T=read_separable4d_csv(filename,kind)
% AI-assisted input plumbing only. Explicit schemas avoid readtable inference.
% Header, delimiter, first data row and column types are fixed and checked.
switch kind
    case 'manifest'
        names=["relative_path","source_path","bytes","sha256"];
        types=["string","string","double","string"];
    case 'audit'
        names=["seed","algorithm_seed","reference","midpoint","lower","upper", ...
            "bracket_width","midpoint_below","upper_below","midpoint_error_percent", ...
            "upper_error_percent","upper_minus_midpoint","midpoint_shift_percent_of_deficit", ...
            "winning_ray","lower_query","upper_query","upper_reason","upper_native_tipo", ...
            "upper_cache_kind","upper_sample_count","upper_end_time", ...
            "first_non_target_below_query","total_non_target_below_queries","total_queries", ...
            "upper_z1","upper_z2","upper_z3","upper_z4"];
        types=repmat("double",size(names));
        types(ismember(names,["midpoint_below","upper_below","upper_reason"]))="string";
    otherwise
        error('Unknown diagnostic CSV schema: %s',kind);
end
fid=fopen(filename,'r','n','UTF-8');
assert(fid>=0,'Cannot open CSV: %s',filename);
guard=onCleanup(@() fclose(fid));
header=fgetl(fid);
assert(ischar(header),'Missing CSV header: %s',filename);
header=erase(string(header),string(char(65279)));
assert(strcmp(strtrim(header),strjoin(names,',')), ...
    'Unexpected CSV header in %s. Expected: %s. Actual: %s', ...
    filename,strjoin(names,','),header);
clear guard;
opts=delimitedTextImportOptions('NumVariables',numel(names));
opts.Delimiter=',';
opts.DataLines=[2,Inf];
opts.VariableNames=cellstr(names);
opts.VariableTypes=cellstr(types);
opts.ExtraColumnsRule='error';
opts.EmptyLineRule='skip';
opts.ImportErrorRule='error';
opts.Encoding='UTF-8';
T=readtable(filename,opts);
assert(isequal(string(T.Properties.VariableNames),names), ...
    'Imported CSV column names do not match the explicit schema.');
end
