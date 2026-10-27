% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function T=experiment_C_domain_read_table(file,requiredNames,numericNames)
% Experiment CSVs always have a comma-separated header on the first line.
if nargin<3, numericNames=strings(0,1); end
assert(isfile(file),'DynInDomain:MissingCSV','CSV does not exist: %s',file);
T=readtable(file,'FileType','text','Delimiter',',', ...
    'ReadVariableNames',true,'NumHeaderLines',0, ...
    'VariableNamingRule','preserve','TextType','string');
names=string(T.Properties.VariableNames);
missing=setdiff(string(requiredNames),names);
assert(isempty(missing),'DynInDomain:CSVSchema', ...
    'CSV schema mismatch in %s. Missing: %s. Imported columns: %s.', ...
    file,strjoin(missing,', '),strjoin(names,', '));
for name=reshape(string(numericNames),1,[])
    assert(ismember(name,names),'DynInDomain:CSVSchema','Missing numeric column: %s',name);
    values=T.(char(name));
    if ~isnumeric(values) && ~islogical(values), values=str2double(string(values)); end
    assert(all(isfinite(values(:))),'DynInDomain:CSVNumeric', ...
        'Column %s contains a missing or nonnumeric value in %s.',name,file);
    T.(char(name))=double(values);
end
end
