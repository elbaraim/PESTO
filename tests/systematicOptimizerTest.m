clear;
clear persistent;
close all;

% add examples to path
addpath('../examples/enzymatic_catalysis');
addpath('../examples/conversion_reaction');

% enzymatic catalysis
ec_nTimepoints = 50;      % Time points of Measurement
ec_nMeasure    = 1;        % Number of experiments
ec_sigma2      = 0.05^2;   % Variance of Measurement noise
ec_theta       = [1.1770; -2.3714; -0.4827; -5.5387]; % True parameter values
ec_yMeasured = getMeasuredData();
ec_con0 = getInitialConcentrations();
ec_fun = @(theta) -logLikelihoodEC(theta, ec_yMeasured, ec_sigma2, ec_con0, ec_nTimepoints, ec_nMeasure);

% conversion reaction
cr_t = (0:10)';
cr_sigma2 = 0.015^2;
cr_y = [0.0244; 0.0842; 0.1208; 0.1724; 0.2315; 0.2634; 0.2831; 0.3084; 0.3079; 0.3097; 0.3324];
cr_lb = [-7;-7];
cr_ub = [3;3];

% Log-likelihood function
cr_fun = @(theta) -logLikelihoodCR(theta, cr_t, cr_y, cr_sigma2, 'log');

%% prepare all test functions

arr_testfunction = { @TestFunctions.sphere, @TestFunctions.rosenbrock, @TestFunctions.booth, @TestFunctions.ackley, ec_fun, cr_fun };
arr_testfunctionname = { 'Sphere', 'Rosenbrock', 'Booth', 'Ackley', 'Enzymatic Catalysis', 'Conversion Reaction' }; 
arr_lb = { [-4;-4], [-2;-1], [-10;-10], [-33;-33], -10*ones(4,1), cr_lb };
arr_ub = { [4;4],   [2;3],   [10;10],   [33;33], 5*ones(4,1), cr_ub   };

%arr_x0 = { [-3;3],  [-1.5;0.5], [-7;7], [-0.5;1.5], [-2.5;-5.5;-2.5;-8.5], [2;-6] };

nTest = length(arr_testfunction);
nStart = 5;
arr_x0 = cell(nTest,1);

for j=1:nTest
    arr_x0{j} = [bsxfun(@plus,arr_lb{j},bsxfun(@times,arr_ub{j} - arr_lb{j},rand(length(arr_ub{j}),nStart)))];
end
    

%% prepare all optimization options
% slightly different name conventions

maxIter     = 2000;
maxFunEvals = 2000;
tolX        = 1e-8;
tolFun      = 1e-8;

options.Display = 'off';
options.MaxIterations = maxIter;
options.MaxIter = maxIter;
options.MaxFunctionEvaluations = maxFunEvals;
options.MaxFunEvals = maxFunEvals;
options.StepTolerance = tolX;
options.TolX = tolX;
options.TolFun = tolFun;
%options.Barrier = 'log-barrier';

%% optimizations


nOpt  = 4;

cells = cell(nOpt,nStart,7);

for j=1:nTest
    fprintf(['\n-------- ', arr_testfunctionname{j},'\n']);
    lb = arr_lb{j};
    ub = arr_ub{j};
    fun = arr_testfunction{j};
    
    %outputFunction = @(x,optimValues,state) outputProgress(x,optimValues,state,fun,lb,ub);
    %options.OutputFcn = outputFunction;
    
    % fmincon
    for k=1:nStart
        time = cputime;
        x0=arr_x0{j}(:,k);
        [x,fval,exitflag,output] = fmincon(fun,x0,[],[],[],[],lb,ub,[],options);
        output.t_cpu = cputime - time;
        %printResult(x,fval,exitflag,output);   
        cells=f_writeToCellMatrix(cells,1,k,fval,exitflag,output.iterations,output.funcCount,output.t_cpu,x);
    end
    
    % fminsearch
    for k=1:nStart
        time = cputime;
        x0=arr_x0{j}(:,k);
        [x,fval,exitflag,output] = fminsearch(fun,x0);
        output.t_cpu = cputime - time;
        %printResult(x,fval,exitflag,output);
        cells=f_writeToCellMatrix(cells,2,k,fval,exitflag,output.iterations,output.funcCount,output.t_cpu,x);
    end
    
    % hctt
    for k=1:nStart
        x0=arr_x0{j}(:,k);
        [x, fval, exitflag, output] = hillClimbThisThing(fun,x0,lb,ub,options);
        %printResult(x,fval,exitflag,output);
        cells=f_writeToCellMatrix(cells,3,k,fval,exitflag,output.iterations,output.funcCount,output.t_cpu,x);
    end
    

    % dhc
    for k=1:nStart
        x0=arr_x0{j}(:,k);
        [x, fval, exitflag, output] = dynamicHillClimb(fun,x0,lb,ub,options);
        %printResult(x,fval,exitflag,output);
        cells=f_writeToCellMatrix(cells,4,k,fval,exitflag,output.iterations,output.funcCount,output.t_cpu,x);
    end
    
    f_printCellMatrix(cells);
end

%% helper functions

function cells = f_writeToCellMatrix(cells,j,k,fval,exitflag,iterations,funcCount,t_cpu,x);
    cells{j,k,1}=j;
    cells{j,k,2}=fval;
    cells{j,k,3}=exitflag;
    cells{j,k,4}=iterations;
    cells{j,k,5}=funcCount;
    cells{j,k,6}=t_cpu;
    cells{j,k,7}=x;
end

function f_printCellMatrix(cells)
    fprintf('Slvr.\t|\tRun\t|\tfval\t|\texitflag\t|\titerations\t|\tfuncCount\t|\tt_cpu\t|\tx\n');
    for j=1:size(cells,1)
        for k=1:size(cells,2)
            fprintf(['%d\t|\t%d\t|\t%.15f\t|\t%d\t|\t%d\t|\t%d\t|\t%.15f\t|\t',mat2str(cells{j,k,7}),'\n'],cells{j,k,1},k,cells{j,k,2},cells{j,k,3},cells{j,k,4},cells{j,k,5},cells{j,k,6});
        end
    end
end