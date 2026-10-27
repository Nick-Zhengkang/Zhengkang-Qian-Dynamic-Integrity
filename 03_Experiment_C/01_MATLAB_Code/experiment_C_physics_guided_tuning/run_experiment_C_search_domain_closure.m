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
function outDir=run_experiment_C_search_domain_closure(sourceDir,alphas,mode,resumeDir)
% Geometric proof plus trajectory stress tests, without GA or reference LIM.
if nargin<2, alphas=[0.2 0.7 1.0]; end
if nargin<3, mode='validate'; end
if nargin<4, resumeDir=''; end
mode=validatestring(mode,{'audit','validate'});
validateattributes(alphas,{'numeric'},{'vector','positive','finite','nonempty'});
alphas=reshape(alphas,1,[]); assert(numel(unique(alphas))==numel(alphas));
here=fileparts(mfilename('fullpath'));
design=struct('version','search_domain_closure_v1','sourceDir',char(sourceDir), ...
    'alphas',alphas,'mode',mode,'angles',24,'fractions',[0.3 0.7 0.999], ...
    'left_insets',[1e-3 1e-6 1e-8],'maximumGrid',2401, ...
    'referenceLIMUsed',false,'gaSearchPerformed',false);
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_search_domain_closure_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); mkdir(outDir);
else
    outDir=char(resumeDir);
    assert(isfile(fullfile(outDir,'protocol.mat')),'Wrong resume directory.');
end
sources={'run_experiment_C_search_domain_closure.m','experiment_C_search_domain_closure.m', ...
    'experiment_C_domain_geometry.m'};
protocolFile=fullfile(outDir,'protocol.mat');
snap=fullfile(outDir,'source_snapshot');
if isfile(protocolFile)
    old=load(protocolFile,'design'); assert(isequaln(old.design,design),'Resume settings changed.');
    for j=1:numel(sources)
        assert(strcmp(fileread(fullfile(here,sources{j})),fileread(fullfile(snap,sources{j}))), ...
            'Resume source changed: %s',sources{j});
    end
else
    mkdir(snap);
    for j=1:numel(sources), copyfile(fullfile(here,sources{j}),snap); end
    save(protocolFile,'design');
end
folders=dir(fullfile(sourceDir,'case_*'));
audits=cell(0,1); decisions=cell(0,1); summaries=cell(0,1); allPoints=table();
fprintf('\nSearch-domain closure: %s, %d damping cases. No GA and no reference LIM.\n%s\n', ...
    mode,numel(alphas),outDir);
for c=1:numel(alphas)
    a=alphas(c); caseDir=fullfile(outDir,sprintf('case_%02d',c));
    if ~isfolder(caseDir), mkdir(caseDir); end
    frozen=fullfile(caseDir,'frozen_inputs.mat');
    if isfile(frozen)
        S=load(frozen); O=S.O; E=S.E; cfg=S.cfg;
    else
        hits=0;
        for j=1:numel(folders)
            src=fullfile(folders(j).folder,folders(j).name);
            file=fullfile(src,'original_domain','domain_settings.mat');
            if ~isfile(file), continue; end
            tmp=load(file);
            if abs(tmp.geo.alpha-a)>1e-12, continue; end
            O=tmp; E=load(fullfile(src,'energy_envelope','domain_settings.mat'));
            data=load(fullfile(src,'input_snapshot','run_configuration.mat'),'cfg'); cfg=data.cfg;
            hits=hits+1;
        end
        assert(hits==1,'Frozen alpha case not uniquely identified.');
        save(frozen,'O','E','cfg');
    end
    assert(abs(O.g.alpha-a)<1e-12 && abs(E.g.alpha-a)<1e-12);
    [gNew,pNew,build]=experiment_C_search_domain_closure('build',O.g,O.p,design.maximumGrid);
    ids=["original_domain","symmetric_energy","anchored_search_energy"];
    gs={O.g,E.g,gNew}; ps={O.p,E.p,pNew};
    candidateReady=false;
    for j=1:3
        g=gs{j}; p=ps{j}; profile=ids(j);
        audit=experiment_C_search_domain_closure('audit',g,p);
        audit.profile=profile;
        audit.same_radius_as_original=abs(audit.initial_search_radius- ...
            min([O.g.target-O.g.domain(1:2),O.g.domain(3:4)-O.g.target]))<1e-12;
        audit.within_grid_limit=p.discr<=design.maximumGrid;
        audits{end+1,1}=audit; %#ok<AGROW>
        profileDir=fullfile(caseDir,char(profile));
        if ~isfolder(profileDir), mkdir(profileDir); end
        save(fullfile(profileDir,'coverage_settings.mat'),'g','p','audit');
        fprintf('[case %d/%d] alpha=%g, %s: R0=%.8g, Ecap=%.8g, N=%d, coverage=%d\n', ...
            c,numel(alphas),a,profile,audit.initial_search_radius, ...
            audit.search_energy_cap,p.discr,audit.exact_energy_envelope_covered);
        if strcmp(mode,'validate')
            Z=probe_points(audit.initial_search_radius,design);
            pointFile=fullfile(profileDir,'trajectory_probes.csv');
            T=read_or_empty(pointFile);
            assert(height(T)<=size(Z,1));
            for k=1:height(T)
                assert(max(abs([T.x0(k),T.v0(k)]-Z(k,:)))<1e-12,'Probe checkpoint mismatch.');
            end
            for k=height(T)+1:size(Z,1)
                r=probe(Z(k,:),k,g,p,cfg,audit.search_energy_cap,profile);
                if isempty(T), T=struct2table(r); else, T=[T;struct2table(r)]; end %#ok<AGROW>
                atomic_csv(T,pointFile);
                fprintf('  [probe %d/%d] %s, domain violation=%d, end t=%.3g\n', ...
                    k,size(Z,1),r.status,r.observed_domain_violation,r.end_time);
            end
            s=struct('alpha',a,'profile',profile,'n_points',height(T), ...
                'n_failures',nnz(T.status~="ok"),'n_observed_domain_violations', ...
                nnz(T.observed_domain_violation),'n_energy_check_failures', ...
                nnz(~T.energy_check_pass),'n_unresolved_tail_coverage', ...
                nnz(~T.tail_envelope_covered),'max_energy_excess',max(T.max_energy_excess), ...
                'geometry_covers_whole_search_ball',audit.exact_energy_envelope_covered, ...
                'all_probes_pass',all(T.status=="ok" & ~T.observed_domain_violation & ...
                T.energy_check_pass & T.tail_envelope_covered));
            summaries{end+1,1}=s; %#ok<AGROW>
            if isempty(allPoints), allPoints=T; else, allPoints=[allPoints;T]; end %#ok<AGROW>
            if j==3
                candidateReady=s.all_probes_pass && audit.exact_energy_envelope_covered && ...
                    audit.same_radius_as_original && audit.within_grid_limit;
            end
        end
    end
    decisions{end+1,1}=struct('alpha',a,'geometry_pass',build.exact_energy_envelope_covered, ...
        'initial_radius_preserved',build.radius_preserved, ...
        'target_belt_preserved',build.max_target_belt_difference<1e-10, ...
        'within_grid_limit',build.within_grid_limit,'trajectory_checks_run',strcmp(mode,'validate'), ...
        'ready_for_next_controlled_GA',candidateReady, ...
        'classification_accuracy_validated',false); %#ok<AGROW>
    atomic_csv(struct2table(vertcat(audits{:})),fullfile(outDir,'search_domain_audit.csv'));
    atomic_csv(struct2table(vertcat(decisions{:})),fullfile(outDir,'coverage_decisions.csv'));
    if ~isempty(summaries)
        atomic_csv(struct2table(vertcat(summaries{:})),fullfile(outDir,'summary_trajectory_coverage.csv'));
        atomic_csv(allPoints,fullfile(outDir,'all_trajectory_probes.csv'));
    end
end
fprintf('\nCoverage audit finished.\nAudit: %s\nDecisions: %s\n', ...
    fullfile(outDir,'search_domain_audit.csv'),fullfile(outDir,'coverage_decisions.csv'));
end

function Z=probe_points(R,design)
theta=((0:design.angles-1)'+0.271)*2*pi/design.angles; Z=zeros(0,2);
for q=design.fractions
    Z=[Z;[-1+q*R*cos(theta),q*R*sin(theta)]]; %#ok<AGROW>
end
% Stress the pinned face and nearly tangent starts, all strictly inside R0.
for e=design.left_insets
    for theta=[pi-1e-5,pi,pi+1e-5]
        Z(end+1,:)=[-1,0]+(1-e)*R*[cos(theta),sin(theta)]; %#ok<AGROW>
    end
end
end

function r=probe(z0,k,g,p,cfg,Ecap,profile)
r=struct('alpha',g.alpha,'profile',profile,'point_id',k,'x0',z0(1),'v0',z0(2), ...
    'initial_energy',energy(z0),'search_energy_cap',Ecap,'max_energy_excess',NaN, ...
    'observed_domain_violation',false,'energy_check_pass',false, ...
    'tail_envelope_covered',false,'end_time',NaN,'wall_s',NaN, ...
    'sampled_xmin',NaN,'sampled_xmax',NaN,'sampled_vmin',NaN,'sampled_vmax',NaN, ...
    'status',"failed",'message',"");
timer=tic;
try
    assert(all(z0>g.domain(1:2) & z0<g.domain(3:4)),'Initial point outside domain.');
    if energy(z0)<-0.01
        t=0; z=z0;
    else
        opts=odeset('RelTol',min(cfg.relTol,1e-10),'AbsTol',min(cfg.absTol,1e-11), ...
            'MaxStep',min(p.Ts,g.period/100),'Events',@trap_event);
        [t,z]=ode45(@(~,z)[z(2);z(1)-z(1)^3-g.alpha*abs(z(2))*z(2)], ...
            [0 p.tfinal],z0,opts);
    end
    en=energy(z); r.max_energy_excess=max(en)-en(1);
    r.energy_check_pass=r.max_energy_excess<=1e-7*max(1,abs(en(1))) && ...
        en(1)<=Ecap+1e-10;
    r.observed_domain_violation=any(any(z<=g.domain(1:2) | z>=g.domain(3:4)));
    % A global terminal-energy envelope covers the unintegrated future.
    b=experiment_C_domain_geometry('energy_bounds',max(-0.25,en(end)));
    r.tail_envelope_covered=all(b(1:2)>=g.domain(1:2)-1e-12) && ...
        all(b(3:4)<=g.domain(3:4)+1e-12);
    r.end_time=t(end); r.sampled_xmin=min(z(:,1)); r.sampled_xmax=max(z(:,1));
    r.sampled_vmin=min(z(:,2)); r.sampled_vmax=max(z(:,2));
    if all(isfinite(z(:))), r.status="ok"; else, r.status="nonfinite"; end
catch ME
    r.message=string(ME.message);
end
r.wall_s=toc(timer);
end

function e=energy(z)
e=0.5*z(:,2).^2-0.5*z(:,1).^2+0.25*z(:,1).^4;
end

function [v,stop,direction]=trap_event(~,z)
v=energy(z(:)')+0.01; stop=1; direction=-1;
end

function T=read_or_empty(file)
T=table(); if isfile(file), T=readtable(file,'TextType','string'); end
end

function atomic_csv(T,file)
[folder,stem,ext]=fileparts(file); tmp=fullfile(folder,[stem '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end
