function verify_ablation_sources(root,data,out)
% AI-assisted audit. All copied source bytes must match the historical archive,
% except exactly two cache-read statements in the ablation step function.
snapshot=fullfile(data,'source_snapshot');
names=["sampled_forward_proposed","sampled_forward_classifier","sampled_forward_geometry", ...
    "sampled_forward_integrate","sampled_forward_step"];
rows=cell(0,1);
for mode=["baseline","no_negative_reuse"]
    for name=names
        original=fullfile(snapshot,'six_model_sampled_forward_comparison',char(name+".m"));
        copied=fullfile(root,'engines',char(mode),char(name+".m"));
        expected=read_bytes(original); change="none";
        if mode=="no_negative_reuse" && name=="sampled_forward_step"
            a=normalize(fileread(original));
            old=sprintf('if any(cellId==g.cell_d), kind=2; end\nif any(cellId==g.cell_dout), kind=3; end');
            replacement=sprintf(['%% AI-assisted ablation: do not read learned non-target or domain-exit labels.\n' ...
                '%% Target-cache reads, direct domain checks and recurrence rules are unchanged.']);
            assert(numel(strfind(a,old))==1,'Expected original cache-read statements not found exactly once.');
            same=strcmp(strrep(a,old,replacement),normalize(fileread(copied)));
            change="remove_two_negative_cache_reads_only";
        else
            same=isequal(expected,read_bytes(copied));
        end
        rows{end+1,1}=record(original,copied,change,same); %#ok<AGROW>
    end
end
shared={ ...
    fullfile('four_model_five_method_suite','functions','+limbench','angular_with_oracle.m'), ...
    fullfile('shared','+limbench','angular_with_oracle.m'); ...
    fullfile('four_model_five_method_suite','functions','+limbench','private','angular_engine.m'), ...
    fullfile('shared','+limbench','private','angular_engine.m'); ...
    fullfile('work','DynIn','DynIn_v1.1.0','functions','find_index.m'), ...
    fullfile('shared','native','find_index.m'); ...
    fullfile('work','DynIn','DynIn_v1.1.0','functions','find_cells_around_a_cell.m'), ...
    fullfile('shared','native','find_cells_around_a_cell.m')};
for k=1:size(shared,1)
    original=fullfile(snapshot,shared{k,1}); copied=fullfile(root,shared{k,2});
    rows{end+1,1}=record(original,copied,"none",isequal(read_bytes(original),read_bytes(copied))); %#ok<AGROW>
end
for id=["quadratic_cubic","bistable_duffing","genda_cosine_quadratic_drag"]
    original=fullfile(data,'dynin_models',char(id),'sistema.m');
    copied=fullfile(root,'models',char(id),'sistema.m');
    rows{end+1,1}=record(original,copied,"none",isequal(read_bytes(original),read_bytes(copied))); %#ok<AGROW>
end
T=struct2table(vertcat(rows{:})); writetable(T,fullfile(out,'source_verification.csv'));
assert(all(T.matches_expected),'Unexpected source changes. See source_verification.csv.');
fprintf('Source audit PASS: %d copies, only the two intended cache-read statements removed.\n',height(T));
end
function r=record(a,b,change,same)
r=struct('original_file',string(a),'copy_file',string(b), ...
    'permitted_change',change,'matches_expected',same);
end
function b=read_bytes(file)
fid=fopen(file,'rb'); assert(fid>=0,'Cannot read %s',file);
guard=onCleanup(@() fclose(fid)); %#ok<NASGU>
b=fread(fid,Inf,'*uint8');
end
function s=normalize(s)
s=strrep(s,sprintf('\r\n'),sprintf('\n'));
end
