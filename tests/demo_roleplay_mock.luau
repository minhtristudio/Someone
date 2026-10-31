local now = 0
local function Signal()
    local handlers = {}
    return { Connect = function(_, f) local t={fn=f,active=true};handlers[#handlers+1]=t;return {Disconnect=function() t.active=false end} end,
        Fire = function(_, ...) for _,h in ipairs(handlers) do if h.active then h.fn(...) end end end }
end
local CFM = {}; CFM.__index = function(self,key) if key=="Position" then return Vector3.new(self.x,self.y,self.z) end;return CFM[key] end
function CFM:GetComponents() return self.x,self.y,self.z,1,0,0,0,1,0,0,0,1 end
function CFM.__mul(a,b) return setmetatable({x=a.x+b.x,y=a.y+b.y,z=a.z+b.z},CFM) end
function CFM:Inverse() return CFrame.new(-self.x,-self.y,-self.z) end
function CFM:ToObjectSpace(b) return self:Inverse()*b end
CFrame = { new=function(x,y,z) if type(x)=="table" then return setmetatable({x=x.X,y=x.Y,z=x.Z},CFM) end;return setmetatable({x=x or 0,y=y or 0,z=z or 0},CFM) end }
CFrame.identity = CFrame.new()
local VM = {}; VM.__index=VM
function VM.__div(a,b) return Vector3.new(a.X/b.X,a.Y/b.Y,a.Z/b.Z) end
function VM.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function VM:Lerp(b,t) return Vector3.new(self.X+(b.X-self.X)*t,self.Y+(b.Y-self.Y)*t,self.Z+(b.Z-self.Z)*t) end
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},VM) end}; CFrame.lookAt=function() return CFrame.identity end
Enum={CollisionFidelity={Box={Value=1}},RenderFidelity={Performance={Value=1}},MeshType={FileMesh={}},EasingStyle={Linear={Name="Linear"}},EasingDirection={InOut={Name="InOut"}}}
local methods, meta = {}, {}
local created = {}
meta.__index=function(self,k) if k=="Parent" then return rawget(self,"_parent") end;return methods[k] end
meta.__newindex=function(self,k,v)
    if k=="Parent" then
        local old=rawget(self,"_parent")
        if old then local idx=table.find(old._children,self);if idx then table.remove(old._children,idx) end end
        rawset(self,"_parent",v)
        if v then table.insert(v._children,self);v.DescendantAdded:Fire(self) end
    else rawset(self,k,v) end
end
function methods:IsA(class)
    return self.ClassName==class or class=="Instance" or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart"))
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
    local out={};local function go(node) for _,c in ipairs(node._children) do out[#out+1]=c;go(c) end end;go(self);return out
end
function methods:FindFirstChild(n) for _,c in ipairs(self._children) do if c.Name==n then return c end end end
function methods:GetAttribute(n) return self._attributes[n] end
function methods:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;self._destroyed=true end
function methods:GetPivot() local root=self.PrimaryPart or self:FindFirstChild("HumanoidRootPart") or self:FindFirstChild("MAIN_SCENERY_PART");return root and root.CFrame or CFrame.identity end
function methods:PivotTo(cf) local delta=cf*self:GetPivot():Inverse();for _,d in ipairs(self:GetDescendants()) do if d:IsA("BasePart") then d.CFrame=delta*d.CFrame end end end
function methods:Clone()
    local map={}
    local function first(old)
        local new=Instance.new(old.ClassName);map[old]=new
        for k,v in pairs(old) do if k~="_parent" and k~="_children" and k~="DescendantAdded" and k~="_attributes" then rawset(new,k,v) end end
        new._attributes=table.clone(old._attributes)
        for _,ch in ipairs(old:GetChildren()) do local c=first(ch);c.Parent=new end
        return new
    end
    local top=first(self)
    for old,new in pairs(map) do for _,field in ipairs({"Part0","Part1","PrimaryPart","Value"}) do if map[old[field]] then rawset(new,field,map[old[field]]) end end end
    return top
end
Instance={new=function(class)
    local v=setmetatable({ClassName=class,Name=class,_children={},_attributes={},DescendantAdded=Signal()},meta)
    created[#created+1] = v
    if v:IsA("BasePart") then v.CFrame=CFrame.identity;v.Size=Vector3.new(1,1,1);v.Transparency=0;v.LocalTransparencyModifier=0;v.Anchored=false;v.MeshId="";v.TextureID="";v.Color={};v.Material={} end
    return v
end}
typeof=function(v) if type(v)=="table" and getmetatable(v)==meta then return "Instance" end return type(v) end
local function node(class,name,parent) local x=Instance.new(class);x.Name=name;x.Parent=parent;return x end
local root=node("Folder","DemoRoleplay")
local scenes=node("Folder","Scenes",root)
local scene=node("Folder","Noob_1",scenes)
local rig=node("Model","Rig",scene)
local main=node("Part","MAIN_SCENERY_PART",rig)
local function placeholder(name,pos,entity)
    local m=node("Model",name,rig);local hr=node("Part","HumanoidRootPart",m);hr.CFrame=CFrame.new(pos,0,0)
    if entity then node("StringValue","Entity_Name_User",m).Value=entity end
end
placeholder("Rig_Player",1);placeholder("Rig_Entity_2",4,"Noob")
local anims=node("Folder","Animations",scene);local anim=node("Animation","EP1_Loop_1",anims);local seq=node("KeyframeSequence","loop",anim);seq.Loop=true
local function pose(parent,name,cf)
    local x=node("Pose",name,parent);x.CFrame=CFrame.new(cf,0,0);x.Weight=1;x.EasingStyle={Name="Linear"};x.EasingDirection={Name="InOut"};return x
end
for _,t in ipairs({0,1}) do
    local key=node("Keyframe","Keyframe",seq);key.Time=t
    local p=pose(key,"MAIN_SCENERY_PART",0)
    local p1=pose(p,">>Rig_Player<<_HumanoidRootPart",0);local t1=pose(p1,">>Rig_Player<<_Torso",2);pose(t1,"ChestBone",5);local h1=pose(t1,">>Rig_Player<<_Head",0);local f1=pose(h1,"MainEXpresion",3);pose(f1,"Check_1",7)
    local p2=pose(p,">>Rig_Entity_2<<_HumanoidRootPart",0);local t2=pose(p2,">>Rig_Entity_2<<_Torso",3);pose(t2,"ChestBone",8);local tail=pose(t2,">>Rig_Entity_2<<_Tail",2);pose(tail,"TailBone",4)
end
local chars=node("Folder","Characters",root)
local function skeleton(parent)
    local m=node("Model","Rig",parent);local hr=node("Part","HumanoidRootPart",m);local torso=node("Part","Torso",m)
    local motor=node("Motor6D","Torso",hr);motor.Part0=hr;motor.Part1=torso;motor.C0=CFrame.new(1,0,0);motor.C1=CFrame.identity
    local head=node("Part","Head",m);local neck=node("Motor6D","Head",torso);neck.Part0=torso;neck.Part1=head;neck.C0=CFrame.new(1,0,0);neck.C1=CFrame.identity
    return m
end
skeleton(chars);local entities=node("Folder","Entity",chars);local noob=node("Folder","Noob",entities);local noobRig=skeleton(noob)
local tail=node("MeshPart","Tail",noobRig);tail.MeshId="rbxasset://Meshes/OX_test.mesh";node("BoolValue","Visible",tail);node("Bone","TailBone",tail).Transform=CFrame.identity
local tailMotor=node("Motor6D","TailJoint",noobRig:FindFirstChild("Torso"));tailMotor.Part0=noobRig:FindFirstChild("Torso");tailMotor.Part1=tail;tailMotor.C0=CFrame.new(1,0,0);tailMotor.C1=CFrame.identity
local function bodyGroup(parent)
    local model=node("Model","Torso",parent);node("Part","MainPart",model);local part=node("MeshPart","demoMesh",model);part.MeshId="rbxasset://Meshes/OX_test.mesh";part.TextureID="rbxasset://Textures/skin.png";part.CFrame=CFrame.new(0.5,0,0);node("Bone","ChestBone",part).Transform=CFrame.identity
end
local parts=node("Folder","Parts",noob);local default=node("Folder","Default",parts);local variants=node("Folder","__Random__",default);local variant=node("Folder","1",variants);bodyGroup(variant)
local profile=node("Folder","Profile",chars);local sophile=node("Folder","Sophile",profile);local naked=node("Model","Naked_1",sophile);bodyGroup(naked)
local face=node("Model","_Face_Rig",sophile);local faceMain=node("Part","MainEXpresion",face);faceMain.Transparency=1
local cheek=node("MeshPart","Check_1",face);cheek.MeshId="rbxasset://Meshes/OX_test.mesh"
local faceMotor=node("Motor6D","Check_1",faceMain);faceMotor.Part0=faceMain;faceMotor.Part1=cheek;faceMotor.C0=CFrame.new(1,0,0);faceMotor.C1=CFrame.identity
local solos=node("Folder","Solo",root);local player=node("Folder","Player",solos);local aa=node("Animation","WalkAnim",player);local ss=node("KeyframeSequence","WalkAnim",aa);ss.Loop=true
for _,time in ipairs({0,1}) do local key=node("Keyframe","Keyframe",ss);key.Time=time;local p=pose(key,"HumanoidRootPart",0);local torso=pose(p,"Torso",time==0 and 4 or 8);if time==1 then torso.EasingStyle={Name="Constant"} end;pose(torso,"ChestBone",9);local h=pose(torso,"Head",0);local f=pose(h,"MainEXpresion",2);pose(f,"Check_1",6) end
local ws=node("Model","Workspace"); workspace=ws
local character=node("Model","Character",ws);local playerRoot=node("Part","HumanoidRootPart",character);playerRoot.CFrame=CFrame.new(10,0,0);playerRoot.LocalTransparencyModifier=.2
local run={RenderStepped=Signal()};local players={LocalPlayer={Name="Tester",Character=character}}
game={GetService=function(_,name) if name=="Players" then return players elseif name=="RunService" then return run elseif name=="TweenService" then return {GetValue=function(_,alpha) return alpha end} else error(name) end end,
    GetObjects=function() return {root} end,HttpGet=function() error("unexpected HTTP") end}
local files={
    ["DemoRoleplayAssets/Meshes-manifest-v2.txt"]="v2\nMeshes/OX_test.mesh\t4\tADF3F363\n",
    ["DemoRoleplayAssets/Meshes/OX_test.mesh"]="data",
    ["DemoRoleplayAssets/DemoRoleplay-2ccc771a.rbxm"]="bad!",
    ["Meshes.zip"]=__MESH_ZIP__,
}
local folders={DemoRoleplayAssets=true}
isfile=function(p) return files[p]~=nil end;readfile=function(p) return files[p] end;writefile=function(p,v) files[p]=v end
isfolder=function(p) return folders[p] or false end;makefolder=function(p) folders[p]=true end;getfilesize=function(p) return files[p] and #files[p] end
getcustomasset=function(p) return "custom://"..p end
local pending={};task={spawn=function(f) pending[#pending+1]=f end,wait=function() end};warn=function(...) print(...) end
local RP={speed=1};RP.now=function() return now end
function RP.clipByKey(key) for _,c in ipairs(RP.clips or {}) do if c.key==key then return c end end end
local System={RP=RP,Env={},_sessionAlive=true};local PlayerData={};local Function={CachedCreateMeshPartAsync=function(asset) local m=Instance.new("MeshPart");m.MeshId=asset;return m end}

-- INSERT ACTUAL DEMO BACKEND HERE

-- The fake model is intentionally the same size as the expected bytes but wrong.
-- The actual cache loader must rewrite it from the embedded base64 and verify CRC.
assert(RP.loadPacks())
assert(files["DemoRoleplayAssets/DemoRoleplay-2ccc771a.rbxm"]=="data")
assert(#RP.clips==2);assert(RP.clips[1].name=="Noob_1 / EP1_Loop_1");assert(RP.clips[1].kind=="scene")
-- Run the deferred optional-archive completion path without real network calls.
local installer=RP.demo.installArchive;RP.demo.installArchive=function() return true end
for _,work in ipairs(pending) do work() end
assert(RP.demo.warnings.Textures==nil and RP.demo.warnings.Musics==nil)
RP.demo.installArchive=installer
local events=0;RP.onChanged(function() events+=1 end)
local ok,err=RP.play(RP.clips[1].key,{me=character});assert(ok,err);assert(playerRoot.LocalTransparencyModifier==1);run.RenderStepped:Fire()
local scene=workspace:FindFirstChild("_DemoRoleplayScene");assert(scene);local p=scene:FindFirstChild("Rig_Player");local e=scene:FindFirstChild("Rig_Entity_2");assert(p and e)
local pt=p:FindFirstChild(">>Rig_Player<<_Torso");local et=e:FindFirstChild(">>Rig_Entity_2<<_Torso");assert(pt.CFrame.x==13,"player pose="..pt.CFrame.x);assert(et.CFrame.x==17,"entity pose="..et.CFrame.x)
local seen={}
for _,d in ipairs(scene:GetDescendants()) do if d:IsA("Bone") and d.Name=="ChestBone" then seen[d.Parent.CFrame.x]=d.Transform.x end end
assert(seen[13.5]==5 and seen[17.5]==8,"scene bone tracks must stay scoped to each actor")
local texturedMesh
for _,d in ipairs(scene:GetDescendants()) do if d:IsA("MeshPart") and d.Name=="demoMesh" then texturedMesh=d end end
assert(texturedMesh and texturedMesh.TextureID=="")
files["DemoRoleplayAssets/Textures/skin.png"]="skin";RP.demo.refreshTextures()
assert(texturedMesh.TextureID=="custom://DemoRoleplayAssets/Textures/skin.png","late demo texture should be applied")
local faceRig=p:FindFirstChild("_Face_Rig");assert(faceRig);local cheek=faceRig:FindFirstChild("Check_1");assert(cheek and cheek.CFrame.x==25,"scene facial pose")
local visibleTail=e:FindFirstChild(">>Rig_Entity_2<<_Tail");assert(visibleTail and visibleTail.Transparency==0 and visibleTail.CFrame.x==20,"visible skinned rig part must stay linked")
local tailBone=visibleTail:FindFirstChild("TailBone");assert(tailBone and tailBone.Transform.x==4,"rig bone track")
RP.stop();assert(playerRoot.LocalTransparencyModifier==.2);assert(not workspace:FindFirstChild("_DemoRoleplayScene"));assert(events==2)
local solo=RP.clips[2];assert(solo.kind=="solo");local sok,why=RP.play(solo.key,{me=character});assert(sok,why);run.RenderStepped:Fire();local so=workspace:FindFirstChild("_DemoRoleplayScene");local tor=so:FindFirstChild("Rig_Player"):FindFirstChild("Torso");assert(tor.CFrame.x==15,"solo pose="..tor.CFrame.x)
local soloBone;for _,d in ipairs(so:GetDescendants()) do if d:IsA("Bone") then soloBone=d end end
assert(soloBone and soloBone.Transform.x==9,"solo bone must use unprefixed pose")
local soloCheek=so:FindFirstChild("Rig_Player"):FindFirstChild("_Face_Rig"):FindFirstChild("Check_1");assert(soloCheek.CFrame.x==25,"solo facial pose")
now=.5;run.RenderStepped:Fire();assert(tor.CFrame.x==15,"Constant pose must hold until the keyframe")
now=1;run.RenderStepped:Fire();assert(tor.CFrame.x==19,"Constant pose must switch on the keyframe");now=0
RP.stop();assert(playerRoot.LocalTransparencyModifier==.2)
-- Speed changes preserve the current phase, and non-looped clips restore visibility.
local sample=RP.sample;local sampledTime
RP.sample=function(data,writers,t) sampledTime=t;sample(data,writers,t) end
now=0;assert(RP.play(solo.key,{me=character}));now=.25;run.RenderStepped:Fire();assert(math.abs(sampledTime-.25)<1e-9)
RP.setSpeed(2);now=.5;run.RenderStepped:Fire();assert(math.abs(sampledTime-.75)<1e-9);RP.stop();RP.setSpeed(1);RP.sample=sample
ss.Loop=false;now=0;assert(RP.play(solo.key,{me=character}));now=2;run.RenderStepped:Fire();assert(not RP.playing() and RP.lastStop=="ended");assert(playerRoot.LocalTransparencyModifier==.2);ss.Loop=true;now=0

-- A missing/corrupt asset must not silently use another body. Reinstall from local ZIP.
files["DemoRoleplayAssets/Meshes/OX_test.mesh"]="bad!"
assert(RP.demo.installArchive("Meshes"));assert(files["DemoRoleplayAssets/Meshes/OX_test.mesh"]=="data")

-- If playback preparation is cancelled, discard the new rig without hiding the avatar.
local oldCreate=Function.CachedCreateMeshPartAsync;local canceled=false
Function.CachedCreateMeshPartAsync=function(...) if not canceled then canceled=true;RP.stop() end;return oldCreate(...) end
local played, reason=RP.play(solo.key,{me=character});assert(not played and reason=="cancelled");assert(playerRoot.LocalTransparencyModifier==.2);assert(not workspace:FindFirstChild("_DemoRoleplayScene"));Function.CachedCreateMeshPartAsync=oldCreate

-- Even failure after hiding started must restore the original visibility.
local oldConnect=character.DescendantAdded.Connect;character.DescendantAdded.Connect=function() error("injected signal failure") end
local fail, message=RP.play(solo.key,{me=character});assert(not fail and message:find("cannot hide"));assert(playerRoot.LocalTransparencyModifier==.2);assert(not workspace:FindFirstChild("_DemoRoleplayScene"));character.DescendantAdded.Connect=oldConnect
local oldRenderConnect=run.RenderStepped.Connect;run.RenderStepped.Connect=function() error("injected render failure") end
local noConn, connErr=RP.play(solo.key,{me=character});assert(not noConn and connErr:find("cannot start"));assert(playerRoot.LocalTransparencyModifier==.2);assert(not workspace:FindFirstChild("_DemoRoleplayScene"));run.RenderStepped.Connect=oldRenderConnect
-- Never substitute an unskinned SpecialMesh when a demo mesh contains bones.
Function.MeshNativeSize=function() return Vector3.new(1,1,1) end
Function.CachedCreateMeshPartAsync=function() return nil,"unsupported" end
local unsupported, unsupportedErr=RP.play(solo.key,{me=character});assert(not unsupported and unsupportedErr:find("cannot create demo mesh"));assert(playerRoot.LocalTransparencyModifier==.2);assert(not workspace:FindFirstChild("_DemoRoleplayScene"));Function.CachedCreateMeshPartAsync=oldCreate

-- Preview uses and disposes the same demo scene rig and camera.
local viewport=node("ViewportFrame","Viewport");local preview=RP.demoPreview(solo,viewport);assert(#viewport:GetChildren()>0);preview.step(0.5);preview.destroy();assert(#viewport:GetChildren()==0)
assert(not RP.pick()); print("mock scene, solo, bone scopes, CRC recovery, cancellation, preview and cleanup passed")
