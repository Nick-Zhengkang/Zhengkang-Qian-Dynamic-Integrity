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
function [bounds,rows]=experiment_C_domain_pilot(D,f,p,cfg,outDir)
% Calibration trajectories only; no numerical-domain stopping event.
% After energy trapping, add a conservative envelope for the remaining path.
file=fullfile(outDir,'pilot_trajectories.csv');
rows=table();
if isfile(file)
    rows=experiment_C_domain_read_table(file,["point_id","x0","v0","status"], ...
        ["point_id","x0","v0"]);
end
D=D(logical(D.inside_domain),:);
assert(height(rows)<=height(D));
for i=1:height(rows)
    assert(rows.point_id(i)==D.point_id(i) && ...
        abs(rows.x0(i)-D.x0(i))<1e-12 && abs(rows.v0(i)-D.v0(i))<1e-12, ...
        'Pilot checkpoint points differ.');
end
for i=height(rows)+1:height(D)
    z0=[D.x0(i) D.v0(i)];
    r=struct('point_id',D.point_id(i),'x0',z0(1),'v0',z0(2), ...
        'xmin',NaN,'vmin',NaN,'xmax',NaN,'vmax',NaN,'end_time',NaN, ...
        'wall_s',NaN,'cpu_s',NaN,'timing_review_flag',false, ...
        'max_energy_increase',NaN,'trapping_reached',false,'status',"failed",'message',"");
    timer=tic; cpu0=cputime;
    try
        E0=energy(z0);
        if E0<=-cfg.oracleEnergyMargin*f.barrier
            t=0; z=z0;
        else
            opts=odeset('RelTol',cfg.oracleRelTol,'AbsTol',cfg.oracleAbsTol, ...
                'MaxStep',f.period/100,'Events',@(t,z)trap_event(t,z,cfg,f));
            [t,z]=ode45(@(t,z)experiment_C_rule_physics('rhs',f.model,f.alpha,z), ...
                [0 p.tfinal],z0,opts);
        end
        E=energy(z);
        r.end_time=t(end); r.max_energy_increase=max([0;diff(E)]);
        r.trapping_reached=E(end)<=-0.5*cfg.oracleEnergyMargin*f.barrier;
        % This exact terminal-energy bound covers the unsimulated tail.
        tail=experiment_C_domain_geometry('energy_bounds',max(E(end),-0.25));
        b=[min(min(z,[],1),tail(1:2)),max(max(z,[],1),tail(3:4))];
        r.xmin=b(1); r.vmin=b(2); r.xmax=b(3); r.vmax=b(4);
        if all(isfinite(z(:))) && r.max_energy_increase<1e-7*max(1,abs(E0))
            r.status="ok";
        else
            r.status="numerical_check_failed";
        end
    catch ME
        r.message=string(ME.message);
    end
    r.wall_s=toc(timer); r.cpu_s=cputime-cpu0;
    r.timing_review_flag=r.wall_s>30 && r.wall_s>5*max(r.cpu_s,1);
    if isempty(rows), rows=struct2table(r); else, rows=[rows;struct2table(r)]; end %#ok<AGROW>
    tmp=fullfile(outDir,'pilot_trajectories_writing.csv');
    writetable(rows,tmp); movefile(tmp,file,'f');
    fprintf('[envelope pilot %d/%d] %s, trapped=%d, %.2fs\n', ...
        i,height(D),r.status,r.trapping_reached,r.wall_s);
end
if any(string(rows.status)~="ok")
    bounds=NaN(1,4);
else
    bounds=[min(rows.xmin),min(rows.vmin),max(rows.xmax),max(rows.vmax)];
end
end

function E=energy(z)
E=0.5*z(:,2).^2-0.5*z(:,1).^2+0.25*z(:,1).^4;
end

function [value,isterminal,direction]=trap_event(~,z,cfg,f)
value=energy(z(:)')+cfg.oracleEnergyMargin*f.barrier;
isterminal=1; direction=-1;
end
