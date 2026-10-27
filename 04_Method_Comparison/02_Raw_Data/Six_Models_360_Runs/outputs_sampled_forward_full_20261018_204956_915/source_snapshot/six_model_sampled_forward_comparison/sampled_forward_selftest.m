function report=sampled_forward_selftest(configs,cases,o)
% Short direct-call parity checks, not a scientific convergence test.
repo=fileparts(fileparts(mfilename('fullpath'))); rows=cell(height(cases),1);
for m=1:height(cases)
    id=char(cases.model_id(m)); d=configs.(id);
    guard=sampled_forward_activate(d,repo); %#ok<NASGU>
    nativeDir=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
    assert(strcmpi(strrep(pwd,'\','/'),strrep(nativeDir,'\','/')), ...
        'Run from the shared functions folder to avoid model-local solver shadowing.');
    assert(strcmpi(strrep(which('sys_solver'),'\','/'), ...
        strrep(fullfile(nativeDir,'sys_solver.m'),'\','/')));
    [p,c,s]=sampled_forward_model(table2struct(cases(m,:)),d,o);
    assert(isequal(d.target,p.target) && isequal(d.weight,p.weight));
    for name={'discr','targetCells','tfinal','Ts','RelTol','AbsTol','repFixPoint','repPeriodic'}
        assert(isequal(d.(name{1}),c.(name{1})));
    end
    assert(~c.retryUnresolved && c.automatic==1 && ~c.checkMinPeriodic);
    assert(abs(d.targetCells/d.discr-d.baseEffectiveK/d.baseDiscr)<1e-12);
    cap=min([sqrt(d.weight).*(p.target-p.lower),sqrt(d.weight).*(p.upper-p.target)]);
    assert(abs(s.maxRadius-cap)<1e-12);
    d.tfinal=4*d.Ts;
    native=sampled_forward_segmented_classifier(d); g=native.state();
    dim=numel(d.target);
    % Independent transcription of compute_LIM_FP's grid setup.
    dh=zeros(dim,1); centers=zeros(d.discr,dim); cell_e=zeros(dim,1);
    for j=1:dim
        dh(j)=(d.domain(dim+j)-d.domain(j))/d.discr;
        centers(:,j)=d.domain(j)+dh(j)/2:dh(j):d.domain(dim+j);
        [~,cell_e(j)]=min(abs(centers(:,j)-d.target(j)));
    end
    cc=[find_index(cell_e,dim,d.discr);find_cells_around_a_cell(dim,cell_e,d.discr,d.targetCells)];
    cd0=zeros(0,1); co=zeros(0,1);
    assert(isequal(g.cell_pos,centers) && isequal(g.dh,dh) && isequal(g.cell_c,cc));
    a=d.target; a(1)=a(1)+.6*cap/sqrt(d.weight(1));
    b=d.target; b(2)=b(2)+.6*cap/sqrt(d.weight(2));
    probes=[d.target;a;a;b;b];
    forced=0; reuse=0; labelDifferences=0; stopDifferences=0;
    nativeTime=0; continuousTime=0;
    for j=1:size(probes,1)
        checkTimer=tic;
        [xt,~,cf,kind,~,count]=simulation_DI(dim,d.par,probes(j,:),d.tfinal,d.Ts, ...
            [d.RelTol,d.AbsTol],d.domain,d.discr,cc,cd0,co,centers,dh, ...
            d.repFixPoint,d.repPeriodic,.005,0,d.weight);
        nativeTime=nativeTime+toc(checkTimer);
        frozen=g; frozen.cell_c=cc; frozen.cell_d=cd0; frozen.cell_dout=co;
        % Same native trajectory samples must produce exactly the same rules.
        prior=cf(1);
        replayKind=0;
        for sample=2:count
            [replayKind,cid]=sampled_forward_step(xt(sample,:),frozen,d,prior);
            assert(cid==cf(sample));
            prior(end+1,1)=cid; %#ok<AGROW>
            if replayKind~=0, assert(sample==count); break; end
        end
        assert(replayKind==kind,'Sampled rule differs from native simulation_DI.');
        checkTimer=tic;
        [~,~,continuousKind,continuousCount]=sampled_forward_integrate(d,frozen,probes(j,:));
        continuousTime=continuousTime+toc(checkTimer);
        % Numerical paths may differ. Report rather than hide disagreement.
        labelDifferences=labelDifferences+(continuousKind~=kind);
        stopDifferences=stopDifferences+(continuousCount~=count);
        [q,calls]=native.classify(probes(j,:),p,c);
        assert(q.native_tipo==kind && calls==count-1 && q.sample_count==count);
        assert(q.forced_non_target==(kind==0));
        rmin=min(sqrt(sum((xt(1:count,:)-d.target).^2.*d.weight,2)));
        assert(abs(q.min_radius-rmin)<1e-12);
        if kind==0, kind=2; end
        expected="non_target"; if kind==1, expected="target"; end
        assert(q.label==expected);
        cf=unique(cf,'stable'); learned=cf(1:end-1);
        if kind==1, cc=[cc;learned]; %#ok<AGROW>
        elseif kind==3, co=[co;learned]; %#ok<AGROW>
        else, cd0=[cd0;learned]; %#ok<AGROW>
        end
        after=native.state();
        assert(isequal(after.cell_c,cc) && isequal(after.cell_d,cd0) && isequal(after.cell_dout,co));
        forced=forced+q.forced_non_target; reuse=reuse+q.grid_cache_hit;
    end
    fresh=sampled_forward_segmented_classifier(d); initial=fresh.state();
    assert(isempty(initial.cell_d) && isempty(initial.cell_dout));
    assert(isequal(initial.cell_c,g.cell_c),'Labels leaked between runs.');
    expired=sampled_forward_segmented_classifier(d,@() false);
    [blocked,n]=expired.classify(d.target);
    assert(n==0 && blocked.label=="unresolved" && ~blocked.forced_non_target);
    assert(blocked.classification_reason=="wall_guard_before_native_query");
    blockedState=expired.state();
    assert(isequal(blockedState,initial),'A rejected query changed learned labels.');
    continuous=sampled_forward_classifier(d);
    [targetResult,n]=continuous.classify(d.target);
    assert(n==1 && targetResult.label=="target" && targetResult.sample_count==2);
    assert(abs(targetResult.end_time-d.Ts)<1e-12 && targetResult.rhs_count>0);
    expiredContinuous=sampled_forward_classifier(d,@() false);
    [blocked,n]=expiredContinuous.classify(d.target);
    assert(n==0 && blocked.label=="unresolved");
    assert(isequal(expiredContinuous.state(),initial));
    sampled_forward_callback_tests(d,g);
    rows{m}=struct('model_id',string(id),'passed',true,'probe_count',size(probes,1), ...
        'forced_horizon_cases',forced,'learned_cell_hits',reuse, ...
        'short_test_horizon',d.tfinal,'scientific_validation',false, ...
        'continuous_kind_differences',labelDifferences,'continuous_stop_differences',stopDifferences, ...
        'segmented_probe_time_s',nativeTime,'continuous_probe_time_s',continuousTime);
    clear guard
end
report=struct2table(vertcat(rows{:}));
fprintf('PASS: sampled rules, single-call callbacks, cache reset and parameter matching for %d models.\n',height(report));
end

